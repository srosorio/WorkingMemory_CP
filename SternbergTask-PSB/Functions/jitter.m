function x = jitter(rng_pair)
% -------------------------------------------------------------------------
% jitter  |  Alavie - Sternberg WM Task Helper
%
% Returns a random value uniformly sampled between two bounds.
%
% USAGE
%   x = jitter([min max])
%
% INPUT
%   rng_pair : 1x2 numeric vector [min max] in seconds
%
% OUTPUT
%   x : random scalar uniformly sampled in [min, max]
%
% EXAMPLE
%   WaitSecs(jitter(P.fix1_range));  % wait random jittered interval
% -------------------------------------------------------------------------

x = rng_pair(1) + (rng_pair(2) - rng_pair(1)) * rand(1,1);

end
