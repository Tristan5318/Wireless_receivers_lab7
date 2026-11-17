function [rxbits, conf] = rx(rxsignal, conf, k)
% Recover bits using downconversion, matched filtering, synchronization,
% and preamble-based carrier frequency and phase estimation.
L = round(conf.f_s/conf.f_sym);
rxbits = zeros(conf.nbits,1);
r = double(rxsignal(:));
t = (0:numel(r)-1)'/conf.f_s;
frequency = conf.f_c + conf.offset;
baseband = 2*r.*exp(-1j*2*pi*frequency*t);
% The RRC matched filter suppresses the image at twice the carrier.
h = rrc_taps(L,conf.rolloff,conf.span);
z = filter(h,1,baseband);
p = make_preamble(conf.npreamble);
% Find the strongest correlation over all possible symbol phases.
% A full matched-filter preamble template also handles pulse transients.
train = zeros(conf.npreamble*L,1);
train(1:L:end) = p;
template = conv(train,h,'full');
template = conv(template,h,'full');
% Search at symbol-rate spacing for each sample phase.
search_end = numel(z)-numel(template)+1;
if search_end < 1
    warning('Recording is too short.');
    return;
end
best = -Inf;
best_start = 1;
% Use a compact training window to reduce correlation cost.
ref = template(1:L:end);
for phase = 1:L
    candidate = z(phase:L:end);
    if numel(candidate) < numel(ref), continue; end
    correlation = conv(candidate,flipud(conj(ref)),'valid');
    [score,ix] = max(abs(correlation));
    if score > best
        best = score;
        best_start = phase+(ix-1)*L;
    end
end
% The first symbol decision is delayed by both RRC filters.
first = best_start + conf.span*L;
needed = conf.npreamble + conf.nbits/2;
indices = first+(0:needed-1)'*L;
if indices(end) > numel(z)
    warning('Recording does not contain a complete payload.');
    return;
end
samples = z(indices);
training = samples(1:conf.npreamble).*p;
% Fit phase drift from the known BPSK preamble.
phase = unwrap(angle(training));
fit = polyfit((0:conf.npreamble-1)',phase,1);
frequency_error = fit(1)*conf.f_sym/(2*pi);
conf.estimated_offset = frequency_error;
phase_correction = exp(-1j*(fit(2)+fit(1)*(0:needed-1)'));

corrected = samples.*phase_correction;
payload = corrected(conf.npreamble+1:end);

% Plot the received QPSK constellation
figure;
plot(real(payload), imag(payload), '.');
hold on;

% Plot the ideal QPSK constellation
ideal = [1+1j, -1+1j, -1-1j, 1-1j]/sqrt(2);
plot(real(ideal), imag(ideal), 'ro', ...
    'MarkerSize', 10, 'LineWidth', 2);

axis equal;
grid on;
xlabel('In-phase');
ylabel('Quadrature');
title('Received QPSK constellation');
legend('Received symbols', 'Ideal QPSK symbols');

% QPSK demapping
bits = [real(payload)<0, imag(payload)<0];
rxbits = reshape(bits.',[],1);


end
