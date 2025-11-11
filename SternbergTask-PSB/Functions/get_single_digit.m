function R = get_single_digit(deadlineAbs, P)
% -------------------------------------------------------------------------
% get_single_digit  |  Alavie - Sternberg WM Task
%
% Waits (blocking) until an **absolute** time for the user to press a single
% numeric digit key [0..9]. Meant for the PROBE/RECALL phase where subjects
% enter digits one by one.
%
% USAGE
%   R = get_single_digit(deadlineAbs)           % keyboard only
%   R = get_single_digit(deadlineAbs, P)        % keyboard or RB stub based on P.input.useKeyboard
%
% INPUTS
%   deadlineAbs : absolute GetSecs() time to stop listening
%   P           : (optional) param struct
%                 - P.input.useKeyboard = true/false
%
% RETURNS struct R:
%   R.madeResponse : true if a digit was captured before deadline
%   R.digit        : numeric digit 0..9 (valid iff madeResponse==true)
%   R.keyName      : the key name, e.g. '1'
%   R.tPress       : GetSecs() timestamp of the keypress
%   R.quit         : true if ESC was pressed (caller should abort task)
%
% NOTES
%   - deadlineAbs is an absolute time, not a duration.
%   - Response-box path is currently a quiet stub: it just waits to deadline.
%   - ESC is treated as an explicit "quit" and reported to caller.
% -------------------------------------------------------------------------

%% 1) Default return
R = struct( ...
    'madeResponse', false, ...
    'digit',        NaN, ...
    'keyName',      '', ...
    'tPress',       NaN, ...
    'quit',         false);

%% 2) Determine input mode (keyboard vs RB stub)
useKeyboard = true;  % default
if nargin >= 2 && ~isempty(P) && isfield(P, 'input') && isfield(P.input, 'useKeyboard')
    useKeyboard = logical(P.input.useKeyboard);
end

%% 3) Response Box path (stub for now)
if ~useKeyboard
    % No RB implemented yet → just idle until deadline
    while GetSecs() < deadlineAbs
        WaitSecs(0.01);
    end
    return;
end

%% 4) Keyboard path
KbName('UnifyKeyNames');
try
    KbReleaseWait(-1);  % make sure previous key is released
catch
    % it's okay if this fails on some systems
end

while GetSecs() < deadlineAbs
    [down, t, kc] = KbCheck(-1);
    if ~down
        continue;
    end

    % ESC: quit signal
    if kc(KbName('ESCAPE'))
        R.quit = true;
        return;
    end

    % Check which key(s)
    idx = find(kc);
    if isempty(idx)
        continue;
    end

    names = KbName(idx);       % can be char or cell
    if iscell(names)
        names = names{1};
    end
    if isempty(names)
        continue;
    end

    % Accept only single ASCII digit 0..9
    ch = upper(names);
    if numel(ch) == 1 && ch >= '0' && ch <= '9'
        R.madeResponse = true;
        R.keyName      = ch;
        R.digit        = double(ch) - double('0');  % convert char → numeric
        R.tPress       = t;
        return;
    end

    % otherwise ignore and keep waiting
end

% timeout → return defaults
end
