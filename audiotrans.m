% Assignment 7: acoustic QPSK transmission experiment.
clear; clc; close all;
conf.audiosystem = 'matlab'; % Change to 'matlab' for real speakers/microphone.
conf.f_s = 48000;
conf.f_sym = 100;
conf.f_c = 4000;
conf.npreamble = 100;
conf.nbits = 2000;
conf.rolloff = 0.22;
conf.span = 20;
conf.offset = 0;
conf.nframes = 1;
conf.tone_test = false;
conf.bitsps = 16;
conf.os_factor = conf.f_s/conf.f_sym;
conf.nsyms = conf.nbits/2;
errors = zeros(conf.nframes,1);
for k=1:conf.nframes
    txbits = randi([0 1],conf.nbits,1);
    [txsignal,conf] = tx(txbits,conf,k);
    txsignal = txsignal/(max(abs(txsignal))+0.3);
    padded = [zeros(conf.f_s,1);txsignal;zeros(conf.f_s,1)];
    switch conf.audiosystem
        case 'bypass'
            rxsignal = padded;
        case 'matlab'
            player = audioplayer([padded,zeros(size(padded))],conf.f_s,conf.bitsps);
            recorder = audiorecorder(conf.f_s,conf.bitsps,1,0);
            record(recorder);
            playblocking(player);
            pause(0.5);
            stop(recorder);
            rxsignal = getaudiodata(recorder);
        otherwise
            error('Use bypass or matlab audio mode.');
    end
    [rxbits,conf] = rx(rxsignal,conf,k);
    errors(k) = nnz(rxbits~=txbits);
    fprintf('Frame %d: %d errors / %d bits\n',k,errors(k),conf.nbits);
end
fprintf('BER = %.6g\n',sum(errors)/(conf.nframes*conf.nbits));
if isfield(conf,'estimated_offset')
    fprintf('Estimated frequency error = %.3f Hz\n',conf.estimated_offset);
end


