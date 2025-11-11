function R = get_tf_response(P, deadlineAbs)
% -------------------------------------------------------------------------
% get_tf_response  |  Alavie - Sternberg WM Task
%
% Waits (blocking) for a True / False response until an **absolute** deadline.
% Supports keyboard right now; response box path is a stub to be filled in
% when hardware is ready.
%
% RETURNS struct R:
%   R.madeResponse : true/false
%   R.isTrue       : true if "True" key pressed (J), false if "False" key (F)
%   R.keyName      : 'J' or 'F'
%   R.tPress       : GetSecs() time of keypress
%   R.rt           : (not filled here; caller can compute tPress - onset)
%
% USAGE
%   R = get_tf_response(P, deadlineAbs)
%
% NOTES
%   - ESCAPE aborts the task with an error.
%   - deadlineAbs is an absolute time (i.e. t0 + window), not a duration.
%   - For EEG timing, caller usually logs at the frame where distractor was shown.
% -------------------------------------------------------------------------

% ---- default return ----
R = struct( ...
    'madeResponse', false, ...
    'isTrue',       false, ...
    'keyName',      '', ...
    'tPress',       NaN, ...
    'rt',           NaN);

% =====================================================================
% 1) Response box path (stub)
% =====================================================================
if isfield(P, 'input') && isfield(P.input, 'useKeyboard') && ~P.input.useKeyboard
    % Placeholder for real RB implementation
    fprintf('[Input] Response Box selected, but not configured yet. Waiting until deadline...\n');
    while GetSecs() < deadlineAbs
        WaitSecs(0.01);
    end
    return;
end

% =====================================================================
% 2) Keyboard path
% =====================================================================
keyTrue  = KbName('j');       % "True"
keyFalse = KbName('f');       % "False"
keyQuit  = KbName('ESCAPE');  % abort

KbReleaseWait;  % make sure no key is being held from before

while GetSecs() < deadlineAbs
    [down, t, kc] = KbCheck(-1);
    if ~down
        continue;
    end

    % ESC aborts whole task
    if kc(keyQuit)
        error('User pressed ESCAPE.');
    end

    % TRUE key
    if kc(keyTrue)
        R.madeResponse = true;
        R.isTrue       = true;
        R.keyName      = 'J';
        R.tPress       = t;
        return;
    end

    % FALSE key
    if kc(keyFalse)
        R.madeResponse = true;
        R.isTrue       = false;
        R.keyName      = 'F';
        R.tPress       = t;
        return;
    end
end

% timeout → return defaults
end
