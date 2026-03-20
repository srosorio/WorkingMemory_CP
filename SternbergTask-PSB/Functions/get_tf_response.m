function R = get_tf_response(P)
% -------------------------------------------------------------------------
% get_tf_response (NO DEADLINE VERSION)
%
% Waits indefinitely for a True / False response.
% After response, waits 500 ms, then returns.
%
% RETURNS struct R:
%   R.madeResponse : true/false
%   R.isTrue       : true if "True" key pressed (J), false if "False" key (F)
%   R.keyName      : 'J' or 'F'
%   R.tPress       : GetSecs() time of keypress
%   R.rt           : (left NaN; caller computes if needed)
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
    fprintf('[Input] Response Box selected, but not configured yet.\n');
    return;
end

% =====================================================================
% 2) Keyboard path (NO DEADLINE)
% =====================================================================
keyTrue  = KbName('j');       
keyFalse = KbName('f');       
keyQuit  = KbName('ESCAPE');  

KbReleaseWait;  % avoid carry-over keypress

while true
    [down, t, kc] = KbCheck(-1);

    if ~down
        WaitSecs(0.001); % reduce CPU load
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
        WaitSecs(0.5);   % <-- NEW: 500 ms pause
        return;
    end

    % FALSE key
    if kc(keyFalse)
        R.madeResponse = true;
        R.isTrue       = false;
        R.keyName      = 'F';
        R.tPress       = t;
        WaitSecs(0.5);   % <-- NEW: 500 ms pause
        return;
    end
end
end