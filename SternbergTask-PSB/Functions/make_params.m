function P = make_params(runProfile, condition, subjectID)
% -------------------------------------------------------------------------
% make_params  |  Alavie - Sternberg WM task
%
% Central place to define ALL high-level parameters for the task:
%   - subject/session metadata
%   - timing of each trial phase
%   - screen / photodiode / trigger config
%   - probe (recall) display style
%   - per-machine overrides
%
% Other scripts should READ from P and not redefine things locally.
%
% USAGE:
%   P = make_params()                                                      % defaults ( 'test' ) 
%   P = make_params('eeg')                                                 % EEG run
%   P = make_params('eyetracker')                                          % EyeLink run
%   P = make_params('both')                                                % EEG + EyeLink
%   P = make_params('test','OFFmed_OFFstim','S001')                        % specify condition/subject
%
% PROFILES:
%   'test'       : windowed, SkipSync=2, mocks all HW, tiny blocks/trials
%   'eeg'        : fullscreen, proper sync, TriggerBox + PD enabled
%   'eyetracker' : fullscreen, proper sync, EyeLink enabled
%   'both'       : fullscreen, proper sync, EEG + EyeLink
%
% NOTE:
%   This file is intended to be the *only* place to edit high-level params
%   Everything else (task steps) should just consume P
% -------------------------------------------------------------------------

%% -------------------- Parse inputs & defaults ---------------------------
if nargin < 1 || isempty(runProfile), runProfile = 'test'; end
if nargin < 2 || isempty(condition),  condition  = 'OFFmed_OFFstim'; end
if nargin < 3 || isempty(subjectID),  subjectID  = 'SUBJ001'; end

runProfile    = lower(runProfile);
validProfiles = {'test','eeg','eyetracker','both'};
if ~ismember(runProfile, validProfiles)
    error('make_params: Unknown runProfile "%s". Use: test | eeg | eyetracker | both.', runProfile);
end

%% -------------------- Session metadata ----------------------------------
P.subjectID   = subjectID;
P.sessionID   = string(datetime('now','Format','yyyyMMdd_HHmmss'));        % e.g. 20251104_101233
P.condition   = condition;                                                 % e.g. OFFmed_OFFstim

%% -------------------- Blocks / Trials -----------------------------------
P.nBlocks     = 2;                                                         % real blocks
P.nTrials     = 10;                                                        % trials per block
P.numCounts   = 10;
P.numDigits   = 5;                                                         % digits per trial

%% -------------------- Timing (sec) --------------------------------------
% Trial structure (current design):
%   Fix (baseline)             : 3–3.5 s
%   Digit ON                   : 0.5 s
%   Post-digit fixation        : 1.5–2.0 s (last one 3–3.5 s)
%   Distractor                 : 20 s window
%   Fix after distractor       : 3–3.5 s
%   Probe (recall)             : ≤ 5 digits, max 100 s total, 1-1.5 s gap

% Baseline fixation
P.fix1_range             = [3.0, 3.5];

% Digit display
P.digit_dur              = 0.5;

% Post-digit fixation
P.postDigitFix_range      = [1.5, 2.0];                                    % digits 1..(N-1)
P.postDigitFix_last_range = [3.0, 3.5];                                    % LAST digit only

% Distractor response window
P.distractor_window      = 20.0;                                           % was 4.0

% Fixation after distractor
P.fix_after_dist_range   = [3, 3.5];

% Probe / recall
P.probe_max_total        = 100.0;                                          % was 15.0
P.probe_max_digits       = 5;
P.probe_max_read         = 15;

%% -------------------- Randomization -------------------------------------
P.digitPool              = 0:9;                                            % choose from 0–9
P.randTrueFalseProb      = 0.5;                                            % 50% of distractors are correct

%% -------------------- Start / Instruction Page --------------------------
P.start.waitForKey       = true;
P.start.message          = 'Press any key to start';

%% -------------------- Photodiode ----------------------------------------
P.photodiode.enabled     = true;                                           % harmless in test mode
P.photodiode.rectPix     = [0 0 65 65];                                    % top-left patch (open_ptb_screen will use this)
P.photodiode.flipDur     = 0.016;                                          % ~1 frame @ 60Hz
P.photodiode.mode        = 'steady';                                       % can be 'flash'
P.photodiode.scope       = 'digits';                                       % or 'custom' with names below
% P.photodiode.names     = {'DIGIT','RECALL','DISTRACTOR'};

%% -------------------- Response device prefs -----------------------------
P.input.responseBox      = false;                                          % future: set true when RB added
P.input.keyboardOK       = true;                                           % always allow keyboard fallback
P.input.useKeyboard      = [];                                             % [] → decide later / ask

%% -------------------- Audio parameters ----------------------------------
P.audio.fs               = 16000;                                          
P.audio.nchannels        = 1;
P.audio.bits             = 16;
P.audio.maxsecs          = 4;
P.audio.threshold        = 0.15;                                           % future: create function
P.audio.silenceDuration  = 0.3;
P.audio.postSilence      = .5;
P.audio.chunkSec         = 0.01;     
P.audio.noiseSecs        = 3;
P.audio.speechSecs       = 5;
P.audio.noiseMultiplier  = 5;
%% -------------------- Screen preferences (base) -------------------------
try
    whichScreen = max(Screen('Screens'));
catch
    whichScreen = 0;
end

P.screen.whichScreen      = whichScreen;
P.screen.fullscreen       = true;                                          % profile may override
P.screen.skipSync         = 0;                                             % 0 = do sync tests
P.screen.bgColor          = 0;                                             % black → good for EEG/PD
P.screen.textColor        = 255;
P.screen.fontName         = 'Arial';
P.screen.textSize         = 120;                                           % depends on monitor
P.screen.strictFullscreen = true;                                          % error if not truly fullscreen

%% -------------------- Trigger / HW integration --------------------------
P.trigger.mode            = 'TriggerBox';                                  % 'TriggerBox' | 'Parallel' | 'NI' | 'None'
P.trigger.pulseMs         = 40;                                             % 2–10 ms is ok but for now I chose 5ms (check later if needed) 

% Eye tracker (check later if needed) 
P.eyelink.enable          = false;
P.eyelink.ip              = '100.1.1.1';
P.eyelink.sampleRateHz    = 1000;
P.eyelink.calibrate       = true;
P.eyelink.calType         = 'HV9';

%% -------------------- Mock flags (base) ---------------------------------
% These may get overridden below by specific runProfile
P.mock.screen             = false;
% P.mock.triggerbox       = true;
% P.mock.eyelink          = true;
% P.mock.responsebox      = true;

%% -------------------- Profile selection ---------------------------------
% P.runProfile               = runProfile;
switch runProfile

    case 'test'
        % Dev-friendly profile: windowed, skip sync, few trials, mocked HW
        P.screen.fullscreen        = false;
        P.screen.skipSync          = 2;
        P.screen.strictFullscreen  = false;

        P.nBlocks                  = 1;
        P.nTrials                  = 1;

        P.mock.triggerbox          = true;
        P.mock.eyelink             = true;
        P.mock.responsebox         = true;

        P.photodiode.enabled       = true;                                 % still draw it for visual check

    case 'eeg'
        % Real EEG run: fullscreen, no sync skip, real TriggerBox
        P.screen.fullscreen        = true;
        P.screen.skipSync          = 0;
        P.screen.strictFullscreen  = true;

        P.mock.triggerbox          = false;                                % real triggers
        P.mock.eyelink             = true;                                 % no eyetracker
        P.mock.responsebox         = true;                                 % keyboard

        P.trigger.mode             = 'TriggerBox';
        P.trigger.pulseMs          = 40;
        P.trigger.comPort          = 'COM7';                               % need to set per machine
        P.trigger.serial.baudBP    = 2000000;
        P.trigger.serial.baudBS    = 115200;
        P.trigger.idleLevel        = uint8(0);
        P.trigger.resetLevel       = 255;
        P.trigger.minGapSec        = 0.010;

        P.photodiode.enabled       = true;

    case 'eyetracker'
        % EyeLink only: fullscreen, real ET, no EEG triggers
        P.screen.fullscreen        = true;
        P.screen.skipSync          = 0;
        P.screen.strictFullscreen  = true;

        P.mock.triggerbox          = true;                                 % no EEG
        P.mock.eyelink             = false;                                % real EyeLink
        P.mock.responsebox         = true;

        P.eyelink.enable           = true;
        P.photodiode.enabled       = true;

    case 'both'
        % EEG + EyeLink together
        P.screen.fullscreen        = true;
        P.screen.skipSync          = 0;
        P.screen.strictFullscreen  = true;

        P.mock.triggerbox          = false;                                % real triggers
        P.mock.eyelink             = false;                                % real EyeLink
        P.mock.responsebox         = true;

        P.eyelink.enable           = true;
        P.photodiode.enabled       = true;
end

%% -------------------- Convenience: keyboard vs RB -----------------------
if P.input.responseBox
    % If/when RB is available: (check later if needed) 
    P.input.useKeyboard = false;
else
    if isempty(P.input.useKeyboard)
        P.input.useKeyboard = true;
    end
end

%% -------------------- Distractor visuals --------------------------------
P.distractor.exprYOffset   = -30;                                          % move expression up/down
P.distractor.instrYOffset  = 120;                                          % move instruction down

%% -------------------- Probe (recall) visuals ----------------------------
P.probe.slotWidthPx        = 80;
P.probe.slotGapPx          = 30;
P.probe.lineYoffset        = 80;
P.probe.digitLineGap       = 60;
P.probe.titleYOffset       = -140;

P.probe.inactiveColor      = [150 150 150];
P.probe.showQuestionMark   = true;
P.probe.qMarkChar          = '?';
P.probe.qMarkYOffset       = -80;
P.probe.r_weight_Graycolor = 0.5;

% display style:
%   'question' → show single '?' each time
%   'lines'    → show dashed/gray slots
P.probe.displayStyle       = 'question';
P.probe.postprobe_range    = [1.0, 1.5];

%% -------------------- Text before start ---------------------------------
P.Text.taskCondition       = 'Same Order';                                   % Same Order | Reverse Order

%% -------------------- Pre-task UI (subject info dialog) -----------------
[P, confirmed] = get_task_info_ui(P);
if ~confirmed
    error('------- User cancelled experiment setup.');
end

%% -------------------- Per-machine tweaks (dev vs stim PC) ---------------
host = getenv('COMPUTERNAME');                                             % Windows host name
P.screen.hostname = host;

switch upper(host)
    case 'CNS-DD3XM3V64'                                                   % My PC
        P.screen.skipSync         = 2;
        P.screen.fullscreen       = true;
        P.screen.strictFullscreen = false;

        % prefer external monitor if present
        try
            P.screen.whichScreen = max(Screen('Screens'));
        catch
            P.screen.whichScreen = 0;
        end

    otherwise  % Stim PC
        P.screen.skipSync         = 0;
        P.screen.fullscreen       = true;
        P.screen.strictFullscreen = true;
        P.mock.triggerbox         = false;   
        P.screen.whichScreen      = 1;
        % optional: P.screen.whichScreen = max(Screen('Screens'));
end

%% -------------------- File saving / paths --------------------------------
% NOTE: this uses P.runProfile below, so make sure caller passes it consistently
path_save_CSV = [char(P.runProfile), '\', P.subjectID, '\', P.condition];

P.saveDir       = fullfile(pwd, 'output', path_save_CSV);
P.audio.saveDir = fullfile(pwd, 'output', path_save_CSV, 'AudioFiles');

if ~exist(P.saveDir,'dir'), mkdir(P.saveDir); end
if ~exist(P.audio.saveDir,'dir'), mkdir(P.audio.saveDir); end

P.csvFile = sprintf('%s_%s_%s_%s_events.csv', ...
    P.subjectID, ...
    P.condition, ...
    strrep(P.Text.taskCondition, " ", "_"), ...
    P.runProfile);

P.edfFile = sprintf('%s_eye.edf', ...
    P.subjectID);

end
