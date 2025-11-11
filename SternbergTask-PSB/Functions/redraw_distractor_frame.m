function redraw_distractor_frame(win, P, S, D)
% -------------------------------------------------------------------------
% redraw_distractor_frame  |  Alavie - Sternberg WM Task Helper
%
% Draws the arithmetic distractor screen:
%   line 1 (centered, slightly up):   "a + b = shownSum"
%   line 2 (centered, lower):         "[J] True      [F] False"
%
% This is called right before flipping, usually via markEvent(...) so the
% distractor onset is photodiode- and trigger-aligned.
%
% INPUTS
%   win : PTB window handle
%   P   : params struct
%         - P.screen.bgColor
%         - P.screen.textColor
%         - Optional: P.text.fontName, P.text.size, P.text.color
%         - Optional: P.distractor.exprYOffset  (default = -30)
%         - Optional: P.distractor.instrYOffset (default = +120)
%   S   : screen struct (expects S.cx, S.cy)
%   D   : distractor struct (from generate_distractor)
%         - D.a, D.b, D.shownSum
%
% NOTE
%   This function only draws to the backbuffer. Call Screen('Flip', win)
%   outside to actually present it.
% -------------------------------------------------------------------------

%% 1) Text style
if isfield(P,'text')
    Screen('TextFont',  win, P.text.fontName);
    Screen('TextSize',  win, P.text.size);
    Screen('TextColor', win, P.text.color);
else
    Screen('TextColor', win, P.screen.textColor);
end

%% 2) Ensure distractor substruct + defaults
if ~isfield(P, 'distractor'),              P.distractor = struct(); end
if ~isfield(P.distractor,'exprYOffset'),   P.distractor.exprYOffset  = -30;  end  % a bit above center
if ~isfield(P.distractor,'instrYOffset'),  P.distractor.instrYOffset = 120;  end  % well below

%% 3) Clear to background
clear_to_bg(win, P.screen.bgColor);

%% 4) Build strings
expr  = sprintf('%d + %d = %d', D.a, D.b, D.shownSum);
instr = '[J] True          [F] False';   % spaced for readability

%% 5) Draw expression (centered, with vertical offset)
DrawFormattedText(win, expr, ...
    'center', S.cy + P.distractor.exprYOffset, ...
    P.screen.textColor);

%% 6) Draw instruction (lower, centered)
DrawFormattedText(win, instr, ...
    'center', S.cy + P.distractor.instrYOffset, ...
    P.screen.textColor);
end
