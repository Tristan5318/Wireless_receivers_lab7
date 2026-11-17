function [txsignal, conf] = tx(txbits, conf, k)
% Transmit a BPSK preamble and QPSK payload.
% k is retained for compatibility with the original interface.

L = conf.f_s / conf.f_sym;
assert(L == round(L), ...
    'The oversampling factor must be an integer.');

txbits = txbits(:);

assert(mod(numel(txbits), 2) == 0, ...
    'QPSK requires an even number of bits.');

assert(numel(txbits) == conf.nbits, ...
    'The input length must equal conf.nbits.');

if isfield(conf, 'tone_test') && conf.tone_test
    t = (0:2*conf.f_s-1)' / conf.f_s;
    txsignal = real(exp(1j*2*pi*conf.f_c*t));
    return;
end

% QPSK mapping
bits = reshape(txbits, 2, []).';
payload = ((1-2*bits(:,1)) + ...
    1j*(1-2*bits(:,2))) / sqrt(2);

% Known BPSK training sequence
preamble = make_preamble(conf.npreamble);
preamble = preamble(:);

assert(numel(preamble) == conf.npreamble, ...
    'Unexpected preamble length.');

symbols = [preamble; payload];

% Upsampling and RRC pulse shaping
upsampled = zeros(numel(symbols)*L, 1);
upsampled(1:L:end) = symbols;

h = rrc_taps(L, conf.rolloff, conf.span);
h = h(:);

baseband = conv(upsampled, h, 'full');

% Real passband signal
t = (0:numel(baseband)-1)' / conf.f_s;
txsignal = real(baseband .* exp(1j*2*pi*conf.f_c*t));

end