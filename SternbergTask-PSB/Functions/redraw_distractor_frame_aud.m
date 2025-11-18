function redraw_distractor_frame_aud(win, P, S, D)
% -------------------------------------------------------------------------
% redraw_distractor_frame  |  Modified Version
%
% Draws ONLY the arithmetic distractor:
%       "a + b = shownSum"
%
% No True/False instruction text is displayed.
% Expression appears centered on the screen.
%
% INPUTS
%   win : PTB window pointer
%   P   : params struct (font, text color, bgColor)
%   S   : screen struct (expects S.cx, S.cy)
%   D   : distractor struct (fields: a, b, shownSum)
% -------------------------------------------------------------------------

%% 1) Text style
if isfield(P, 'text')
    Screen('TextFont',  win, P.text.fontName);
    Screen('TextSize',  win, P.text.size);
    Screen('TextColor', win, P.text.color);
else
    Screen('TextColor', win, P.screen.textColor);
end

%% 2) Clear to background
clear_to_bg(win, P.screen.bgColor);

%% 3) Build the arithmetic expression
expr = sprintf('%d + %d = %d', D.a, D.b, D.shownSum);

%% 4) Draw the expression centered on screen
DrawFormattedText(win, expr, 'center', 'center', P.screen.textColor);

end