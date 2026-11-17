clear; clc; close all;

fs = 48000;
fc = 4000;
duration = 2;

t = (0:1/fs:duration-1/fs)';
signal = 0.2*cos(2*pi*fc*t);

player = audioplayer(signal,fs,16);
recorder = audiorecorder(fs,16,1);

record(recorder);
pause(0.5);

playblocking(player);

pause(0.5);
stop(recorder);

received = getaudiodata(recorder);

figure;
plot((0:length(received)-1)/fs,received);
xlabel('Time [s]');
ylabel('Amplitude');
title('Recorded microphone signal');
grid on;