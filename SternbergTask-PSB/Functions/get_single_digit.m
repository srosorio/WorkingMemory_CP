function R = get_single_digit(P)
% -------------------------------------------------------------------------
% get_single_digit (NO DEADLINE VERSION + isTrue field)
%
% Waits indefinitely for a single numeric digit key [0..9].
% After response, waits 500 ms, then returns.
%
% RETURNS struct R:
%   R.madeResponse : true if a digit was captured
%   R.isTrue       : true if a valid digit was entered (for compatibility)
%   R.digit        : numeric digit 0..9
%   R.keyName      : the key name, e.g. '1'
%   R.tPress       : GetSecs() timestamp of the keypress
%   R.quit         : true if ESC was pressed
% -------------------------------------------------------------------------

%% 1) Default return
R = struct( ...
    'madeResponse', false, ...
    'isTrue',       false, ...
    'digit',        NaN, ...
    'keyName',      '', ...
    'tPress',       NaN, ...
    'quit',         false);

%% 2) Determine input mode
useKeyboard = true;
if nargin >= 1 && ~isempty(P) && isfield(P, 'input') && isfield(P.input, 'useKeyboard')
    useKeyboard = logical(P.input.useKeyboard);
end

%% 3) Response Box path (stub)
if ~useKeyboard
    fprintf('[Input] Response Box selected, but not configured yet.\n');
    return;
end

%% 4) Keyboard path
KbName('UnifyKeyNames');

try
    KbReleaseWait(-1);
catch
end

while true
    [down, t, kc] = KbCheck(-1);

    if ~down
        WaitSecs(0.001);
        continue;
    end

    % ESC → quit
    if kc(KbName('ESCAPE'))
        R.quit = true;
        return;
    end

    % Identify pressed key
    idx = find(kc);
    if isempty(idx)
        continue;
    end

    names = KbName(idx);
    if iscell(names)
        names = names{1};
    end
    if isempty(names)
        continue;
    end

    % Normalize keypad input (e.g., 'KP_1' → '1')
    if startsWith(names, 'KP_')
        ch = names(end);
    elseif endsWith(names, '!')
        ch = names(1);
    else
        ch = upper(names);
    end

    % Accept only single digit
    if numel(ch) == 1 && ch >= '0' && ch <= '9'
        R.madeResponse = true;
        % R.isTrue       = true;   % <-- NEW FIELD
        R.keyName      = ch;
        R.digit        = double(ch) - double('0');
        R.tPress       = t;

        WaitSecs(0.5);
        return;
    end
end
end