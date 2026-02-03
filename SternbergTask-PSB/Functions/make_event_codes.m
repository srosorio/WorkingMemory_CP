function C = make_event_codes()
% -------------------------------------------------------------------------
% make_event_codes
% Alavie - Sternberg WM task
%
% Purpose
%   Central place to define ALL event / trigger codes (8-bit safe: 1..255)
%   so that:
%     - Psychtoolbox task sends consistent triggers
%     - EEG/LFP analysis scripts can map codes → events
%     - everyone in the lab uses the same dictionary
%
% Notes
%   - Many events come in ON/OFF pairs to make photodiode alignment easier.
%   - Per-digit and per-probe slots are defined as VECTORS so the task can
%     index them per position.
%   - If you add new task phases, do it here so we keep a single source of truth.
% -------------------------------------------------------------------------

%% ------------------------------------------------------------------------
%  SESSION / UI
% -------------------------------------------------------------------------
C.SESSION_START     = 1;    % whole session begins (after UI confirmed)
C.CONFIG_SAVED      = 2;    % params/UI saved
C.SESSION_END       = 3;    % experiment ended cleanly
C.START_PAGE_ON     = 4;    % "Press any key to start" screen shown
C.START_KEYPRESS    = 5;    % subject/experimenter actually pressed start

%% ------------------------------------------------------------------------
%  MIC SET UP
% -------------------------------------------------------------------------
C.MIC_TEST_START    = 6;
C.MIC_TEST_END      = 7;

%% ------------------------------------------------------------------------
%  BLOCK / TRIAL FLOW
% -------------------------------------------------------------------------
C.BLOCK_START       = 10;   % start of a block
C.BLOCK_END         = 11;   % end of a block

C.BLOCK_SCREEN_ON   = 12;   % (optional) block-ready screen shown
C.BLOCK_START_KEY   = 13;   % (optional) keypress to go to next block

C.TRIAL_START       = 20;   % start of trial
C.TRIAL_END         = 21;   % end of trial
C.TRIAL_CHANGE      = 22;   % trial transition marker (log-only)
C.DIGITREAD_START   = 23;   % start of digit counting sequence
C.DIGITREAD_END     = 24;   % end of digit counting sequence

%% ------------------------------------------------------------------------
%  FIXATION BEFORE DIGITS
% -------------------------------------------------------------------------
C.FIX1_ON           = 30;   % baseline fixation ON
C.FIX1_OFF          = 31;   % baseline fixation OFF

%% ------------------------------------------------------------------------
%  DIGITS (GENERIC + PER-DIGIT)
% -------------------------------------------------------------------------
% generic codes (not always used when per-digit codes exist)
C.DIGIT_ON          = 40;
C.DIGIT_OFF         = 41;

%% ------------------------------------------------------------------------
%  DISTRACTOR PHASE
% -------------------------------------------------------------------------
C.DISTRACTOR_ON     = 50;   % math expr shown
C.DISTRACTOR_ANS    = 51;   % subject answered T/F
C.DISTRACTOR_OFF    = 52;   % distractor cleared

%% ------------------------------------------------------------------------
%  FIXATION AFTER DISTRACTOR
% -------------------------------------------------------------------------
C.FIX2_ON           = 60;
C.FIX2_OFF          = 61;

%% ------------------------------------------------------------------------
% legacy / experimental
% -------------------------------------------------------------------------
C.PROBE_LINE_ON      = 70;   % legacy (refresh line)
C.PROBE_SLOT_REVEAL  = 75;   % a new solid line (slot) becomes visible; value=slotIndex

%% ------------------------------------------------------------------------
%  PROBE / RECALL PHASE
%  supports both "question" mode (show '?') and "line" mode
% -------------------------------------------------------------------------
C.PROBE_DIGIT_OK    = 71;   % subject successfully entered one probe digit
C.PROBE_TIMEOUT     = 72;   % probe ended because of time
C.PROBE_DONE        = 73;   % probe phase fully done (save entered string)
C.RECALL_BLACK_ON   = 74;   % black page right before first recall prompt

%% ------------------------------------------------------------------------
%  PHOTODIODE (if you want to log PD patch separately)
% -------------------------------------------------------------------------
C.PD_ON             = 90;
C.PD_OFF            = 91;

%% ------------------------------------------------------------------------
%  CORRECTNESS FLAGS (log-only – analysis can look for these)
% -------------------------------------------------------------------------
C.ANS_CORRECT       = 100;
C.ANS_WRONG         = 200;

%% ------------------------------------------------------------------------
%  MISC / UTILITY
% -------------------------------------------------------------------------
C.SANITY_PULSE      = 255;  % quick pulse to test trigger line(s)

%% ------------------------------------------------------------------------
%  PRE-BLOCK 15-DIGIT WARM-UP / VOCAL CHECK
% -------------------------------------------------------------------------
C.DIGIT_READING_ON_IDX   = 101:115; 
C.DIGIT_READING_OFF_IDX  = 116:130;  
C.POSTREAD_FIX_ON_IDX    = 201:215;
C.POSTREAD_FIX_OFF_IDX   = 216:230;
C.COUNT_READ_ALOUD       = 171:185;

% per-digit ON/OFF (for 5-digit Sternberg)
% task uses: C.DIGIT_ON_IDX(k) / C.DIGIT_OFF_IDX(k)
C.DIGIT_ON_IDX      = [141 142 143 144 145];  % digit#1..#5 ON
C.DIGIT_OFF_IDX     = [146 147 148 149 150];  % digit#1..#5 OFF

%% ------------------------------------------------------------------------
%  POST-DIGIT FIXATION (PER DIGIT)
%  shown after each digit to avoid flicker / hold attention
% -------------------------------------------------------------------------
C.POSTDIG_FIX_ON_IDX    = [151 152 153 154 155];  % after digit#k ON
C.POSTDIG_FIX_OFF_IDX   = [156 157 158 159 160];  % after digit#k OFF

% per-slot / per-prompt codes
% shown when a new recall slot / question mark is displayed
C.DIGIT_RECALL_LINE  = [161 162 163 164 165];  % show slot/#1..#5
C.DIGIT_RECALL_INPUT = [166 167 168 169 170];  % trigger per entered digit

end
