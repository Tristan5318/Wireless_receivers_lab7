function [rxbits, conf] = rx(rxsignal, conf, k)
% Joint timing/frequency acquisition followed by fine carrier correction.

rxbits = [];
conf.rx_ok = false;
conf.estimated_offset = NaN;
conf.sync_score = NaN;
conf.first_sample = NaN;
conf.failure_reason = '';

L = conf.f_s / conf.f_sym;
assert(L == round(L), ...
    'The oversampling factor must be an integer.');

assert(mod(conf.nbits, 2) == 0, ...
    'QPSK requires an even number of bits.');

Np = conf.npreamble;
needed = Np + conf.nbits/2;

p = make_preamble(Np);
p = p(:);

assert(numel(p) == Np && all(abs(p) > 0), ...
    'Invalid preamble.');

r = double(rxsignal(:));

if isempty(r) || any(~isfinite(r))
    conf.failure_reason = 'Empty or invalid recording.';
    return;
end

% Remove microphone DC
r = r - mean(r);

% Receiver oscillator, including the injected offset
t = (0:numel(r)-1)' / conf.f_s;
receiver_frequency = conf.f_c + conf.offset;

baseband = 2*r .* exp(-1j*2*pi*receiver_frequency*t);

% Matched filtering
h = rrc_taps(L, conf.rolloff, conf.span);
h = h(:);
z = filter(h, 1, baseband);

% Search only where a full frame can fit.
% "first" is already a symbol decision location.
max_first = numel(z) - (needed-1)*L;

if max_first < 1
    conf.failure_reason = 'Recording too short for a complete frame.';
    return;
end

% Frequency hypotheses are residual frequencies AFTER downconversion.
if isfield(conf, 'cfo_grid')
    frequency_grid = conf.cfo_grid;
else
    frequency_grid = -20:0.5:20;
end

if isfield(conf, 'sync_threshold')
    sync_threshold = conf.sync_threshold;
else
    sync_threshold = 0.35;
end

% Precompute the frequency-rotated preamble templates.
symbol_times = (0:Np-1)' / conf.f_sym;

references = p .* exp( ...
    1j*2*pi*symbol_times*frequency_grid(:).');

reference_energy = sum(abs(p).^2);

best_score = -Inf;
best_first = NaN;
best_frequency = NaN;

% Search all sample phases and coarse frequency hypotheses.
for sample_phase = 1:L

    candidate = z(sample_phase:L:end);

    if numel(candidate) < Np
        continue;
    end

    starts = sample_phase + ...
        (0:numel(candidate)-Np)'*L;

    nvalid = nnz(starts <= max_first);

    if nvalid == 0
        continue;
    end

    starts = starts(1:nvalid);

    window_energy = conv( ...
        abs(candidate).^2, ones(Np,1), 'valid');

    window_energy = window_energy(1:nvalid);

    peak_energy = max(window_energy);

    if peak_energy <= eps
        continue;
    end

    % Reject very weak windows, such as leading/trailing silence.
    energetic = window_energy >= 0.05*peak_energy;

    for g = 1:numel(frequency_grid)

        ref = references(:,g);

        correlation = conv( ...
            candidate, flipud(conj(ref)), 'valid');

        correlation = correlation(1:nvalid);

        score = abs(correlation) ./ ...
            sqrt(reference_energy*window_energy + eps);

        score(~energetic) = -Inf;

        [peak_score, ix] = max(score);

        if peak_score > best_score
            best_score = peak_score;
            best_first = starts(ix);
            best_frequency = frequency_grid(g);
        end
    end
end

conf.sync_score = best_score;

if isnan(best_first) || best_score < sync_threshold
    conf.failure_reason = 'Preamble acquisition failed.';
    return;
end

conf.first_sample = best_first;

% Extract the complete frame at the detected symbol timing.
indices = best_first + (0:needed-1)'*L;
samples = z(indices);

% First remove the coarse frequency estimate.
n = (0:needed-1)';

coarse_corrected = samples .* exp( ...
    -1j*2*pi*best_frequency*n/conf.f_sym);

% Remove known preamble modulation.
training = coarse_corrected(1:Np) .* conj(p);

% Avoid preamble edges, which are more affected by transients and
% the transition from BPSK training to QPSK payload.
edge = min(ceil(conf.span/2), floor((Np-3)/2));
fit_indices = (1+edge:Np-edge)';
fit_n = fit_indices - 1;

training_phase = unwrap(angle(training(fit_indices)));

% Estimate remaining phase slope and constant phase.
coefficients = polyfit(fit_n, training_phase, 1);

fine_frequency = ...
    coefficients(1)*conf.f_sym/(2*pi);

conf.estimated_offset = best_frequency + fine_frequency;

corrected = coarse_corrected .* exp( ...
    -1j*(coefficients(2) + coefficients(1)*n));

% Estimate overall gain from the preamble.
gain = median(abs(corrected(fit_indices)));

if ~isfinite(gain) || gain <= eps
    conf.failure_reason = 'Invalid received signal gain.';
    conf.estimated_offset = NaN;
    return;
end

corrected = corrected / gain;
payload = corrected(Np+1:end);

% QPSK demapping, matching tx.m
bit_pairs = [real(payload)<0, imag(payload)<0];
rxbits = double(reshape(bit_pairs.', [], 1));

conf.rx_ok = true;
conf.failure_reason = '';

% Optional constellation plot
if isfield(conf, 'plot_constellation') && conf.plot_constellation

    figure(100);
    clf;

    plot(real(payload), imag(payload), '.');
    hold on;

    ideal = [1+1j, -1+1j, -1-1j, 1-1j] / sqrt(2);

    plot(real(ideal), imag(ideal), 'ro', ...
        'MarkerSize', 10, 'LineWidth', 2);

    axis equal;
    grid on;

    xlabel('In-phase');
    ylabel('Quadrature');

    title(sprintf( ...
        'Frame %d: injected %.1f Hz, estimated residual %.2f Hz', ...
        k, conf.offset, conf.estimated_offset));

    legend('Received symbols', 'Ideal QPSK symbols');
    drawnow;
end

end