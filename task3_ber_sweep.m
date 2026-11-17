% Task 3: BER versus symbol rate in the bypass channel.
% For acoustic measurements, set mode to 'matlab' and reduce frame count.
clear; close all;
fs=48000; fc=4000; rates=[100 200 400 600 800 1000 1200 1600 2000];
Nframes=3; Nbits=2000; BER=zeros(size(rates));
for i=1:numel(rates)
    conf=struct('f_s',fs,'f_sym',rates(i),'f_c',fc,...
        'npreamble',100,'nbits',Nbits,'rolloff',0.22,...
        'span',20,'offset',0,'tone_test',false);
    if mod(fs,rates(i))~=0
        fprintf('Skipping %d: noninteger oversampling factor.\n',rates(i));
        BER(i)=NaN; continue;
    end
    errors=0;
    for k=1:Nframes
        bits=randi([0 1],Nbits,1);
        [s,conf]=tx(bits,conf,k);
        s=s/(max(abs(s))+0.3);
        % Add silence before and after transmission
        padded = [zeros(fs,1); s; zeros(fs,1)];

        % Configure audio playback and recording
        player = audioplayer([padded, zeros(size(padded))], fs, 16);
        recorder = audiorecorder(fs, 16, 1, 0);

        % Start recording before playback
        record(recorder);

        % Transmit the acoustic signal
        playblocking(player);

        % Record the remaining signal
        pause(0.5);
        stop(recorder);

        % Retrieve the microphone recording
        r = getaudiodata(recorder);
        [detected,conf]=rx(r,conf,k);
        errors=errors+nnz(bits~=detected);
    end
    % Add silence before and after transmission
padded = [zeros(fs,1); s; zeros(fs,1)];

% Configure audio playback and recording
player = audioplayer([padded, zeros(size(padded))], fs, 16);
recorder = audiorecorder(fs, 16, 1, 0);

% Start recording before playback
record(recorder);

% Transmit the acoustic signal
playblocking(player);

% Record the remaining signal
pause(0.5);
stop(recorder);

% Retrieve the microphone recording
r = getaudiodata(recorder);
    BER(i)=errors/(Nframes*Nbits);
    fprintf('Rate %d sym/s: BER %.5g\n',rates(i),BER(i));
end
figure; semilogy(rates,max(BER,0.5/(Nframes*Nbits)),'o-'); grid on;
xlabel('Symbol rate (symbols/s)'); ylabel('BER');
title('BER versus symbol rate (zero-error points shown at detection floor)');
