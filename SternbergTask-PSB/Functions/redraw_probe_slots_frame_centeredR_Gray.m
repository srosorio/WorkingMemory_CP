function redraw_probe_slots_frame_centeredR_Gray(win, P, S, enteredDigits, visibleSlots, leftShift, plot_entered)
% -------------------------------------------------------------------------
% redraw_probe_slots_frame_centeredR_Gray
% Alavie - probe display helper (centered active slot, gray history)
%
% Draws the probe (recall) layout where:
%   - the CURRENT/ACTIVE slot is always centered
%   - previous slots stay to the LEFT (do not re-center)
%   - inactive/previous slots are gray
%   - optional "?" can appear above the active slot
%
% This is the version used for the "progressively reveal slots" probe style. 
% Use the previous version if need others :)
%
% INPUTS
%   win           : PTB window handle
%   P             : params struct (expects P.probe.* and P.screen.*)
%   S             : screen struct (expects S.cx, S.cy)
%   enteredDigits : (kept for API compatibility; not used here) - previous version
%   visibleSlots  : how many slots should be drawn (1..P.probe_max_digits)
%   leftShift     : shift for animation (usually 0); active slot is shifted
%   plot_entered  : kept for API compatibility (ignored) - previous version
%
% STYLE (from make_params → P.probe.*):
%   P.probe.slotWidthPx
%   P.probe.slotGapPx
%   P.probe.lineYoffset
%   P.probe.digitLineGap
%   P.probe.titleYOffset
%   P.probe.inactiveColor
%   P.probe.showQuestionMark
%   P.probe.qMarkChar
%   P.probe.qMarkYOffset
%
% NOTE
%   - This function only draws; caller must Screen('Flip', win).
%   - Active slot is centered; older slots do NOT shift when a new one appears.
% -------------------------------------------------------------------------

if nargin < 6, leftShift = 0; end
if nargin < 7, plot_entered = false; end %#ok<NASGU>  % kept for compatibility

%% ---------- 1) Ensure probe substruct + quick default helper ----------
if ~isfield(P,'probe'), P.probe = struct(); end

% tiny helper to read P.probe fields with defaults
getp = @(f,v) (isfield(P.probe,f) && ~isempty(P.probe.(f))) * P.probe.(f) + ...
              (~(isfield(P.probe,f) && ~isempty(P.probe.(f)))) * v;

%% ---------- 2) Geometry / layout params ----------
W            = getp('slotWidthPx',   80);    % line width
G            = getp('slotGapPx',     30);    % gap between lines
lineY        = S.cy + getp('lineYoffset', 80);
gap          = getp('digitLineGap',  60);    % kept for compatibility
titleYOffset = getp('titleYOffset', -140);

%% ---------- 3) Question-mark options ----------
showQ    = getp('showQuestionMark', false);
qChar    = getp('qMarkChar', '?');
qYOffset = getp('qMarkYOffset', -80);

%% ---------- 4) Colors (normalize to RGB) ----------
activeCol   = toRGB(P.screen.textColor);
inactiveCol = toRGB(getp('inactiveColor', [160 160 160]));
bgCol       = toRGB(P.screen.bgColor);

%% ---------- 5) Text style for title / '?' ----------
if isfield(P,'text') && ~isempty(P.text)
    Screen('TextFont',  win, P.text.fontName);
    Screen('TextSize',  win, P.text.size);
    Screen('TextColor', win, toRGB(P.text.color));
else
    Screen('TextColor', win, activeCol);
end

%% ---------- 6) Clear bg + title ----------
Screen('FillRect', win, bgCol);
DrawFormattedText(win, 'Answer', 'center', S.cy + titleYOffset, activeCol);

%% ---------- 7) Draw slots: history left, active centered ----------
nVis = max(1, min(visibleSlots, P.probe_max_digits));   % clamp to max
step = W + G;

for i = 1:nVis
    if i == nVis
        % ---- ACTIVE slot: always centered (optionally shifted for animation) ----
        cx  = S.cx - leftShift;
        col = activeCol;
    else
        % ---- HISTORY: stays to the left, does NOT get shifted ----
        dx  = (nVis - i) * step;              % farthest (oldest) goes farther left
        cx  = (S.cx - dx);
        % use probe-defined gray weight if available
        col = GrayIndex(win, P.probe.r_weight_Graycolor);
        % col = inactiveCol;  % alternative: use explicit inactive color
    end

    % Slot rect
    xL = cx - W/2;
    xR = cx + W/2;

    % ensure blending
    Screen('BlendFunction', win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    % draw line as a thick rect for reliable gray
    Screen('FillRect', win, col, [xL, lineY-3, xR, lineY+3]);

    % Optional question mark ABOVE ACTIVE slot (only when not animating)
    if showQ && (i == nVis) && leftShift == 0
        qRect = [xL, lineY + qYOffset - 40, xR, lineY + qYOffset + 40];
        DrawFormattedText(win, qChar, 'center', 'center', col, [], [], [], 1.2, [], qRect);
    end
end

end

% -------------------------------------------------------------------------
% helper: toRGB
% Accept scalar (0..255) or 1x3 RGB and return 1x3 double
% -------------------------------------------------------------------------
function rgb = toRGB(c)
if isscalar(c)
    rgb = [c c c];
elseif numel(c) == 3
    rgb = double(c(:))';
else
    rgb = [255 255 255];  % fallback
end
rgb = double(rgb);
end
