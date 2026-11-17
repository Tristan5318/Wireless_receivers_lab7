function r = acoustic_capture(s, fs, micID)

s = s(:);

% Preserve the original amplitude scaling.
s = s / (max(abs(s)) + 0.3);

% One second of silence before and after the waveform.
padded = [zeros(fs,1); s; zeros(fs,1)];

% Original routing: transmit through the left output channel.
playback = [padded, zeros(size(padded))];

player = audioplayer(playback, fs, 16);
recorder = audiorecorder(fs, 16, 1, micID);

% Ensure recording stops if playback raises an error.
cleanup = onCleanup(@() stop(recorder));

record(recorder);
pause(0.25);

playblocking(player);

pause(0.5);
stop(recorder);

r = getaudiodata(recorder);
r = r(:);

end