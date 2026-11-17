function p = make_preamble(N)
% Deterministic BPSK training symbols, shared by transmitter and receiver.
rngstate = rng;
rng(731,'twister');
p = 1-2*randi([0 1],N,1);
rng(rngstate);
end
