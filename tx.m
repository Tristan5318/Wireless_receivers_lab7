function [txsignal, conf] = tx(txbits, conf, k)
% Transmit a BPSK preamble and QPSK payload over a real acoustic channel.
L = conf.f_s / conf.f_sym;
assert(L == round(L), 'The oversampling factor must be an integer.');
if isfield(conf,'tone_test') && conf.tone_test
    t = (0:2*conf.f_s-1)'/conf.f_s;
    txsignal = real(exp(1j*2*pi*conf.f_c*t));
    return;
end
bits = reshape(txbits, 2, []).';
payload = ((1-2*bits(:,1)) + 1j*(1-2*bits(:,2)))/sqrt(2);
preamble = make_preamble(conf.npreamble);
symbols = [preamble; payload];
upsampled = zeros(numel(symbols)*L,1);
upsampled(1:L:end) = symbols;
h = rrc_taps(L, conf.rolloff, conf.span);
baseband = conv(upsampled,h,'full');
t = (0:numel(baseband)-1)'/conf.f_s;
txsignal = real(baseband.*exp(1j*2*pi*conf.f_c*t));
end
