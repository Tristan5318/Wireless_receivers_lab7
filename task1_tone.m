
% Task 1: Real acoustic transmission of an unmodulated carrier
clear; clc; close all;

info = audiodevinfo;

for k = 1:length(info.input)
    fprintf('ID: %d | Name: %s\n', ...
        info.input(k).ID, info.input(k).Name);
end

%% Seleziona esclusivamente il microfono USB
usbIdx = find(contains({info.input.Name}, 'USB PnP Audio Device'), 1);

if isempty(usbIdx)
    error('Microfono USB non trovato. Collega il dispositivo e riprova.');
end

micID = info.input(usbIdx).ID;
fprintf('Microfono selezionato: ID %d | %s\n', ...
    micID, info.input(usbIdx).Name);

%% Parameters
fs = 48000;
fc = 4000;
duration = 2;

%% Generate the baseband signal
t = (0:1/fs:duration-1/fs)';
sBB = ones(size(t));

%% Upconversion
sPB = real(sBB .* exp(1j*2*pi*fc*t));

% Reduce amplitude to avoid speaker saturation
sPB = 0.2 * sPB;

%% Acoustic transmission and recording
player = audioplayer(sPB, fs, 16);
recorder = audiorecorder(fs, 16, 1, micID);

disp('Recording and transmitting...');

% Start recording before playback
record(recorder);
pause(0.5);

% Play the signal through the speakers
playblocking(player);

pause(0.5);
stop(recorder);

% Retrieve the recorded signal
rx_signal = getaudiodata(recorder);

disp('Transmission completed.');

%% Downconversion
t_rx = (0:length(rx_signal)-1)' / fs;

rDC = 2 * rx_signal .* exp(-1j*2*pi*fc*t_rx);

%% Low-pass filtering
% Moving average over one carrier period
N = round(fs/fc);
rBB = filter(ones(N,1)/N, 1, rDC);

%% Plot results
figure;

subplot(3,1,1);
plot(t(1:200), sPB(1:200));
title('Transmitted 4 kHz carrier');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

subplot(3,1,2);
plot(t_rx, rx_signal);
title('Recorded acoustic signal');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

subplot(3,1,3);
plot(t_rx, real(rBB));
hold on;
plot(t_rx, imag(rBB));
legend('Real', 'Imaginary');
title('Downconverted received baseband');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

