function wait_for_start(P, S, L, C, msg)
% -------------------------------------------------------------------------
% wait_for_start  |  Alavie WM task
%
% Show the "start / press any key" page and block until the participant
% presses a key. This is aligned with photodiode + trigger
% because the actual draw is done via markEvent.
%
% Logs:
%   C.START_PAGE_ON:    when the start page is actually drawn (PD+trigger)
%   C.START_KEYPRESS:   when a key is pressed (CSV only)
%
% ESC key aborts the run.
%
% INPUTS
%   P, S : params and screen structs
%   L, C : logger and event codes
%   msg  : optional string to display (defaults to "Press any key to start")
% -------------------------------------------------------------------------

if nargin < 5 || isempty(msg)
    msg = 'Press any key to start';
end

% 1) Show start page via markEvent so PD/trigger align to this flip
markEvent(P, L, S, C.START_PAGE_ON, 'START_PAGE_ON', ...
    struct('note','start page'), ...
    @(w) draw_start_page(w, P, msg));

% 2) Prepare keyboard
KbName('UnifyKeyNames');
RestrictKeysForKbCheck([]);       % allow all keys
try
    KbReleaseWait(-1);            % make sure previous key is released
catch
    % ok if it fails (older PTB / no device)
end

% 3) Wait for any key (ESC aborts)
while true
    [down, t_key, kc] = KbCheck(-1);
    if ~down
        continue;
    end
    if kc(KbName('ESCAPE'))
        error('Start aborted by user (ESC).');
    end
    break;
end

% 4) Log keypress (CSV only; no extra flip here)
event_logger('add', L, 'START_KEYPRESS', C.START_KEYPRESS, t_key, 0, struct());

% 5) Clear screen after key
clear_to_bg(S.win, P.screen.bgColor);
Screen('Flip', S.win);
WaitSecs(0.3);
end

% =====================================================================
% helper: draw the start page
% =====================================================================
function draw_start_page(win, P, msg)
% Draw the start/instruction message on the current background.

% set text style (if P.text exists, use it; otherwise fall back to screen)
if isfield(P,'text')
    Screen('TextFont',  win, P.text.fontName);
    Screen('TextSize',  win, P.text.size);
    Screen('TextColor', win, P.text.color);
else
    Screen('TextColor', win, P.screen.textColor);
end

% clear background
clear_to_bg(win, P.screen.bgColor);

% choose text color
if isfield(P,'text') && isfield(P.text,'color')
    col = P.text.color;
else
    col = P.screen.textColor;
end

% center text
DrawFormattedText(win, msg, 'center', 'center', col);
end
