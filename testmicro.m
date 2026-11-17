clear; clc; close all;

fs = 48000;
duration = 5;

% Select the microphone
recorder = audiorecorder(fs, 16, 1, 0);

disp('Recording for 5 seconds...');
disp('Speak or clap near the microphone.');

recordblocking(recorder, duration);

% Retrieve recorded samples
y = getaudiodata(recorder);

% Display the maximum amplitude
fprintf('Maximum amplitude: %.8f\n', max(abs(y)));
fprintf('RMS amplitude: %.8f\n', sqrt(mean(y.^2)));

% Plot the recorded signal
t = (0:length(y)-1)/fs;

figure;
plot(t, y);
xlabel('Time [s]');
ylabel('Amplitude');
title('Microphone recording test');
grid on;

% Play the recording
sound(y, fs);
