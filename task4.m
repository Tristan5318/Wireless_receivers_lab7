% Task 4: receiver oscillator offset and BER measurement
clear;
clc;
close all;

%% Select the USB microphone

info = audiodevinfo;

for k = 1:numel(info.input)
    fprintf('ID: %d | Name: %s\n', ...
        info.input(k).ID, info.input(k).Name);
end

usbIdx = find(contains( ...
    {info.input.Name}, 'USB PnP Audio Device'), 1);

if isempty(usbIdx)
    error('USB microphone not found. Connect it and retry.');
end

micID = info.input(usbIdx).ID;

fprintf('\nSelected microphone: ID %d | %s\n\n', ...
    micID, info.input(usbIdx).Name);

%% Parameters

fs = 48000;
offsets = -10:2:10;
Nbits = 2000;
Nframes = 3;

conf = struct( ...
    'f_s', fs, ...
    'f_sym', 1000, ...
    'f_c', 4000, ...
    'npreamble', 100, ...
    'nbits', Nbits, ...
    'rolloff', 0.22, ...
    'span', 20, ...
    'offset', 0, ...
    'tone_test', false, ...
    'cfo_grid', -20:0.5:20, ...
    'sync_threshold', 0.35, ...
    'plot_constellation', false);

BER = NaN(size(offsets));
estimated = NaN(size(offsets));

failedFrames = zeros(size(offsets));
successfulFrames = zeros(size(offsets));
comparedBits = zeros(size(offsets));

%% Acoustic experiment

for i = 1:numel(offsets)

    errors = 0;
    estimates = NaN(Nframes,1);

    fprintf('Receiver offset: %+g Hz\n', offsets(i));

    for k = 1:Nframes

        bits = randi([0 1], Nbits, 1);

        % Transmitter remains at the nominal carrier.
        txconf = conf;
        txconf.offset = 0;

        [s, ~] = tx1(bits, txconf, k);

        r = acoustic_capture(s, fs, micID);

        % Apply the oscillator offset only at the receiver.
        rxconf = conf;
        rxconf.offset = offsets(i);

        [decoded, result] = rx1(r, rxconf, k);

        if ~result.rx_ok

            failedFrames(i) = failedFrames(i) + 1;

            fprintf('  Frame %d FAILED: %s\n', ...
                k, result.failure_reason);

            continue;
        end

        frame_errors = nnz(decoded ~= bits);

        errors = errors + frame_errors;
        comparedBits(i) = comparedBits(i) + Nbits;
        successfulFrames(i) = successfulFrames(i) + 1;

        estimates(k) = result.estimated_offset;

        fprintf(['  Frame %d: BER = %.4g, ' ...
                 'residual = %+.3f Hz, sync = %.3f\n'], ...
            k, frame_errors/Nbits, ...
            result.estimated_offset, result.sync_score);
    end

    if comparedBits(i) > 0
        BER(i) = errors / comparedBits(i);

        valid_estimates = estimates(isfinite(estimates));
        estimated(i) = mean(valid_estimates);
    end

    fprintf('  Successful frames: %d/%d\n\n', ...
        successfulFrames(i), Nframes);
end

frameFailureRate = failedFrames / Nframes;

%% Numerical results

results = table( ...
    offsets(:), ...
    BER(:), ...
    frameFailureRate(:), ...
    successfulFrames(:), ...
    estimated(:), ...
    'VariableNames', { ...
        'InjectedOffset_Hz', ...
        'BER_DecodedFrames', ...
        'FrameFailureRate', ...
        'SuccessfulFrames', ...
        'EstimatedResidual_Hz'});

disp(results);

%% BER plot

% Zero observed errors cannot be displayed directly on a log axis.
% Display those points at 0.5 / comparedBits as a plotting convention.
berForPlot = BER;

zeroBER = BER == 0 & comparedBits > 0;
berForPlot(zeroBER) = 0.5 ./ comparedBits(zeroBER);

figure;

semilogy(offsets, berForPlot, 'o-', 'LineWidth', 1.2);
hold on;

if any(zeroBER)
    semilogy(offsets(zeroBER), berForPlot(zeroBER), ...
        'kv', 'MarkerFaceColor', 'k');
end

grid on;
xlabel('Receiver frequency offset (Hz)');
ylabel('BER on successfully decoded frames');
title({ ...
    'BER after frequency correction', ...
    'Zero-error points displayed at 0.5 / compared bits'});

%% Frame acquisition failures

figure;

plot(offsets, frameFailureRate, 's-', 'LineWidth', 1.2);

grid on;
ylim([0 1]);
xlabel('Receiver frequency offset (Hz)');
ylabel('Frame failure rate');
title('Fraction of frames that could not be acquired');

%% Frequency estimates

figure;

plot(offsets, estimated, 'o-', 'LineWidth', 1.2);
hold on;

plot(offsets, -offsets, '--', 'LineWidth', 1.2);

grid on;
legend('Estimated residual', 'Expected residual', ...
    'Location', 'best');

xlabel('Injected receiver offset (Hz)');
ylabel('Residual frequency before correction (Hz)');
title('Preamble-based frequency estimation');