function [t_on, L] = markEvent(P, L, S, code, eventName, extra, redrawFcn)
% -------------------------------------------------------------------------
% markEvent
% Alavie – frame-based event helper
%
% Draw frame: (optionally) draw photodiode → flip → send trigger → log.
%
% PD is shown ONLY for:
%   - digit ON events (names starting with "DIGIT" and ending with "_ON")
%   - the distractor onset ("DISTRACTOR_ON")
%   - probe recall line events ("DIGIT_RECALL_LINE...")
%
% Everything else (fixations, OFF events, black pages, ...) → PD OFF.
%
% This keeps display, trigger, and log all on the same timeline so EEG /
% photodiode traces match what the subject saw.
% -------------------------------------------------------------------------

if nargin < 6 || isempty(extra), extra = struct(); end
if nargin < 7,                    redrawFcn = [];   end

% -------------------------------------------------------------------------
% 1) Headless / no-screen path
% -------------------------------------------------------------------------
if ~isfield(S,'win') || isempty(S.win) || S.win == 0
    t_on = GetSecs();
    % still log + trigger in headless mode
    event_logger('add', L, eventName, code, t_on, 0, extra);
    if ~isfield(P,'mock') || ~isfield(P.mock,'triggerbox') || ~P.mock.triggerbox
        send_trigger_unified('send', P, code, P.trigger.pulseMs);
    end
    return;
end

win   = S.win;
bgcol = P.screen.bgColor;

% -------------------------------------------------------------------------
% 2) Decide if THIS event should show the photodiode
% -------------------------------------------------------------------------
showPD = should_show_pd(eventName);

% -------------------------------------------------------------------------
% 3) Draw the stimulus frame for this event
% -------------------------------------------------------------------------
if ~isempty(redrawFcn)
    redrawFcn(win);
else
    Screen('FillRect', win, bgcol);
end

% -------------------------------------------------------------------------
% 4) Draw photodiode patch (top-left) if enabled + this event uses PD
% -------------------------------------------------------------------------
if isfield(P,'photodiode') && isfield(P.photodiode,'enabled') && P.photodiode.enabled && showPD
    Screen('FillRect', win, 255, S.pdRect);
end

% -------------------------------------------------------------------------
% 5) Flip to screen (this is the actual ON time for this event)
% -------------------------------------------------------------------------
t_on = Screen('Flip', win);

% -------------------------------------------------------------------------
% 6) Send trigger AFTER the flip (for better alignment)
% -------------------------------------------------------------------------
if ~isfield(P,'mock') || ~isfield(P.mock,'triggerbox') || ~P.mock.triggerbox
    send_trigger_unified('send', P, code, P.trigger.pulseMs);
end

% -------------------------------------------------------------------------
% 7) Log the event (include whether PD was used for this frame)
% -------------------------------------------------------------------------
extra.pd_used = double(showPD);   % <-- per-event PD flag for CSV
event_logger('add', L, eventName, code, t_on, 0, extra);

end


% =========================================================================
% decide which events should light the photodiode
% =========================================================================
function tf = should_show_pd(eventName)
% Decide based on the exact rule in the task:
%   - digit ON events
%   - distractor ON
%   - probe recall lines

ev = upper(eventName);

% 1) DIGITS (only the ONs): e.g. 'DIGIT1_ON'
if startsWith(ev, 'DIGIT') && endsWith(ev, '_ON')
    tf = true;
    return;
end

% 2) Distractor onset
if strcmp(ev, 'DISTRACTOR_ON')
    tf = true;
    return;
end

% 3) Probe line shown
%    e.g. 'DIGIT_RECALL_LINE_1', 'DIGIT_RECALL_LINE_2', ...
if startsWith(ev, 'DIGIT_RECALL_LINE')
    tf = true;
    return;
end

% everything else → no photodiode
tf = false;
end
