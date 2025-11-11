function D = generate_distractor(P)
% -------------------------------------------------------------------------
% generate_distractor  |  Alavie - Sternberg WM Task Helper
%
% Builds one arithmetic distractor trial for the Sternberg WM task.
% Randomly generates two operands (a, b) from P.digitPool and determines
% whether to show a correct or incorrect sum.
%
% RETURNS struct D with fields:
%   D.a, D.b      : randomly chosen operands (0–9)
%   D.trueSum     : the actual sum (a + b)
%   D.shownSum    : the number shown to participant (may be wrong)
%   D.isCorrect   : logical → true if shownSum == trueSum (ground truth)
%
% USAGE
%   D = generate_distractor(P)
%
% DEPENDS ON
%   P.digitPool           : vector of digits to sample from
%   P.randTrueFalseProb   : probability of showing a *correct* sum
%
% NOTES
%   - If incorrect, shownSum differs by ±1–3 (never equals trueSum).
%   - Keeps simple arithmetic range suitable for WM task display.
% -------------------------------------------------------------------------

% 1) Pick two operands
D.a = P.digitPool(randi(numel(P.digitPool)));
D.b = P.digitPool(randi(numel(P.digitPool)));
D.trueSum = D.a + D.b;

% 2) Decide if shown sum is correct or not
D.isCorrect = (rand < P.randTrueFalseProb);

if D.isCorrect
    D.shownSum = D.trueSum;
else
    % pick a wrong number near the true sum (±1..±3), but not equal
    deltas = [-3 -2 -1 1 2 3];
    D.shownSum = D.trueSum + deltas(randi(numel(deltas)));
end
end
