% Task 4: inject a receiver oscillator offset and measure the BER.
clear; close all;
fs=48000; offsets=-10:2:10; Nbits=2000; Nframes=3;
conf=struct('f_s',fs,'f_sym',400,'f_c',4000,...
    'npreamble',100,'nbits',Nbits,'rolloff',0.22,...
    'span',20,'offset',0,'tone_test',false);
BER=zeros(size(offsets)); estimated=zeros(size(offsets));
for i=1:numel(offsets)
    errors=0; estimates=zeros(Nframes,1);
    for k=1:Nframes
        bits=randi([0 1],Nbits,1);
        [s,conf]=tx(bits,conf,k);
        s=s/(max(abs(s))+0.3);
        r=[zeros(round(0.1*fs),1);s;zeros(round(0.1*fs),1)];
        conf.offset=offsets(i);
        [decoded,conf]=rx(r,conf,k);
        errors=errors+nnz(decoded~=bits);
        estimates(k)=conf.estimated_offset;
    end
    BER(i)=errors/(Nframes*Nbits);
    estimated(i)=mean(estimates);
end
figure; semilogy(offsets,max(BER,0.5/(Nframes*Nbits)),'o-'); grid on;
xlabel('Receiver frequency offset (Hz)'); ylabel('BER');
title('BER after preamble-based frequency correction');
figure; plot(offsets,estimated,'o-'); hold on; plot(offsets,-offsets,'--');
grid on; legend('Estimated residual','Expected residual');
xlabel('Injected offset (Hz)'); ylabel('Frequency error (Hz)');
