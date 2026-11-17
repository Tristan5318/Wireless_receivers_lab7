function h = rrc_taps(L, beta, span)
% Create a unit-energy root-raised-cosine FIR pulse.
t = (-span/2*L:span/2*L)'/L;
h = zeros(size(t));
for n = 1:numel(t)
    x = t(n);
    if abs(x) < 1e-10
        h(n) = 1 + beta*(4/pi-1);
    elseif beta > 0 && abs(abs(x)-1/(4*beta)) < 1e-10
        h(n) = beta/sqrt(2)*((1+2/pi)*sin(pi/(4*beta)) + ...
            (1-2/pi)*cos(pi/(4*beta)));
    else
        h(n) = (sin(pi*x*(1-beta)) + 4*beta*x*cos(pi*x*(1+beta))) / ...
            (pi*x*(1-(4*beta*x)^2));
    end
end
h = h/sqrt(sum(abs(h).^2));
end
