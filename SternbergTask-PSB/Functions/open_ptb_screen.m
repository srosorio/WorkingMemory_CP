function S = open_ptb_screen(P)
% -------------------------------------------------------------------------
% open_ptb_screen  |  Alavie - PTB screen opener for WM task
%
% Opens a Psychtoolbox window in (preferably) true fullscreen, sets text,
% blending, and computes the photodiode patch rect.
%
% RETURNS struct S:
%   S.win    : PTB window handle
%   S.rect   : window rect [left top right bottom]
%   S.ifi    : inter-frame interval (sec)
%   S.cx,cy  : screen center in pixels
%   S.pdRect : photodiode patch rect (in window coords)
%
% BEHAVIOR
%   - Enforces your P.screen settings (bgColor, textColor, fontName, textSize)
%   - Tries robust fullscreen with PsychImaging first
%   - Falls back to classic Screen() fullscreen
%   - Falls back to windowed-fullscreen if needed
%   - Warns if window doesn't fully cover display (DPI 125% etc.)
%
% NOTE
%   For the stim PC you can flip the final warning to an error to force 100% coverage.
% -------------------------------------------------------------------------

%% 1) Basic PTB preflight
AssertOpenGL;                 % make sure PTB is OK
KbName('UnifyKeyNames');      % normalize key names across OS

%% 2) Validate / fill required fields in P
if ~isfield(P,'screen'), error('P.screen struct missing.'); end

if ~isfield(P.screen,'whichScreen')
    P.screen.whichScreen = max(Screen('Screens'));
end
if ~isfield(P.screen,'bgColor'),     P.screen.bgColor   = 0;      end
if ~isfield(P.screen,'textColor'),   P.screen.textColor = 255;    end
if ~isfield(P.screen,'fontName'),    P.screen.fontName  = 'Arial';end
if ~isfield(P.screen,'textSize'),    P.screen.textSize  = 64;     end
if ~isfield(P.screen,'skipSync'),    P.screen.skipSync  = 0;      end

% photodiode fallback
if ~isfield(P,'photodiode') || ~isfield(P.photodiode,'rectPix')
    P.photodiode.rectPix = [0 0 100 100];
end

%% 3) Global PTB prefs (verbosity, sync, gamma)
Screen('Preference','Verbosity',        4);               % more logs while debugging
Screen('Preference','VisualDebugLevel', 3);               % PTB splash + timing
Screen('Preference','SkipSyncTests',    P.screen.whichScreen);
PsychDefaultSetup(2);                                      % blending/gamma defaults

%% 4) Target screen + expected rect
screens = Screen('Screens');
scr     = P.screen.whichScreen;
if ~ismember(scr, screens)
    scr = max(screens);                                   % fall back to highest id
end
scrRect = Screen('Rect', scr);                            % expected full framebuffer

bg  = P.screen.bgColor;
win = [];
rect = [];

%% 5) Attempt 1: PsychImaging true fullscreen
try
    PsychImaging('PrepareConfiguration');
    PsychImaging('AddTask','General','UseFastOffscreenWindows');
    [win, ~] = PsychImaging('OpenWindow', scr, bg);
    rect = Screen('Rect', win);
catch ME1
    sca;
    fprintf(2,'[open_ptb_screen] First open failed: %s\n', ME1.message);
end

%% 6) Attempt 2: classic Screen() fullscreen
if isempty(win)
    try
        [win, ~] = Screen('OpenWindow', scr, bg, []);     % [] is fullscreen
        rect = Screen('Rect', win);
        fprintf('[open_ptb_screen] Used classic Screen(''OpenWindow'') fallback.\n');
    catch ME2
        sca;
        fprintf(2,'[open_ptb_screen] Classic fullscreen failed: %s\n', ME2.message);
    end
end

%% 7) Attempt 3: windowed-fullscreen to exact scrRect
if isempty(win)
    try
        [win, ~] = Screen('OpenWindow', scr, bg, scrRect);
        rect = Screen('Rect', win);
        fprintf('[open_ptb_screen] Used windowed-fullscreen fallback.\n');
    catch ME3
        sca;
        error('[open_ptb_screen] All open attempts failed: %s', ME3.message);
    end
end

%% 8) Final coverage check
rect = Screen('Rect', win);  % make sure we have the final rect
if any(rect ~= scrRect)
    % For dev: warn
    % For rig: change to error(...) to force 100% coverage
    warning(['[open_ptb_screen] Window not covering full display.\n' ...
             'Got      [%d %d %d %d]\nExpected [%d %d %d %d]\n' ...
             'If on Windows, set "Scale & layout" to 100%% for this monitor.'], ...
             rect, scrRect);
end

%% 9) Configure visuals (font, blending, priority, cursor)
% HideCursor(win);
Priority(MaxPriority(win));

Screen('TextFont',  win, P.screen.fontName);
Screen('TextSize',  win, P.screen.textSize);
Screen('TextColor', win, P.screen.textColor);
Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

ifi       = Screen('GetFlipInterval', win);
[cx, cy]  = RectCenter(rect);

%% Photodiode patch (bottom-right)
pd = P.photodiode.rectPix;   % [0 0 w h]
pd_w = pd(3);
pd_h = pd(4);

right = rect(3);
bottom = rect(4);

left = right  - pd_w;
top  = bottom - pd_h;

pdRect = [left, top, left + pd_w, top + pd_h];

%% 11) Return struct
S.win    = win;
S.rect   = rect;
S.ifi    = ifi;
S.cx     = cx;
S.cy     = cy;
S.pdRect = pdRect;

%% 12) Clear once to background
Screen('FillRect', win, bg);
Screen('Flip', win);

fprintf('[open_ptb_screen] ✅ Fullscreen opened on screen #%d (%dx%d)\n', ...
    scr, rect(3)-rect(1), rect(4)-rect(2));
end
