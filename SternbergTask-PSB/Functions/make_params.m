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
%   P = make_params()                                                      % defaults ('test')
%   P = make_params('eeg')                                                 % EEG run
%   P = make_params('eyetracker')                                          % eye tracker run
%   P = make_params('fullSetup')                                           % EEG + eye tracker
%   P = make_params('test','OFFmed_OFFstim','S001')                        % specify condition/subject
%
% PROFILES:
%   'test'       : windowed, SkipSync=2, mocks all HW, tiny blocks/trials
%   'eeg'        : fullscreen, proper sync, TriggerBox + PD enabled
%   'eyetracker' : fullscreen, proper sync, eye tracker enabled (no EEG)
%   'fullSetup'  : fullscreen, proper sync, EEG + eye tracker
%
% EYE TRACKER:
%   Selected in the UI dialog via P.eyetracker.system:
%     'eyelink'    – SR Research EyeLink
%     'pupil_labs' – Pupil Labs Neon via HTTP REST API
%     'none'       – disabled
%   After the UI, enable flags (P.eyelink.enable, P.neon.enable) are set
%   automatically based on this choice.
%
% NOTE:
%   This file is intended to be the *only* place to edit high-level params.
%   Everything else (task steps) should just consume P.
% -------------------------------------------------------------------------

%% -------------------- Parse inputs & defaults ---------------------------
if nargin < 1 || isempty(runProfile), runProfile = 'test';           end
if nargin < 2 || isempty(condition),  condition  = 'offmed_offstim'; end
if nargin < 3 || isempty(subjectID),  subjectID  = 'SUBJ001';        end

runProfile    = lower(runProfile);
validProfiles = {'test','eeg','eyetracker','fullsetup'};
if ~ismember(runProfile, validProfiles)
    error('make_params: Unknown runProfile "%s". Use: test | eeg | eyetracker | fullSetup.', runProfile);
end

%% -------------------- Session metadata ----------------------------------
P.subjectID  = subjectID;
P.sessionID  = string(datetime('now','Format','yyyyMMdd_HHmmss'));
P.condition  = condition;
P.block      = 'b01';
P.runProfile = runProfile;        % FIX: was commented out in previous version

%% -------------------- Blocks / Trials -----------------------------------
P.nBlocks   = 1;
P.nTrials   = 10;
P.numCounts = 15;
P.numDigits = 5;

%% -------------------- Timing (sec) --------------------------------------
P.fix1_range              = [3.0, 3.5];
P.digit_dur               = 0.5;
P.postDigitFix_range      = [1.5, 2.0];
P.postDigitFix_last_range = [3.0, 3.5];
P.distractor_window       = 20.0;
P.fix_after_dist_range    = [3, 3.5];
P.probe_max_total         = 100.0;
P.probe_max_digits        = 5;
P.probe_max_read          = 15;

%% -------------------- Randomization -------------------------------------
P.digitPool         = 0:9;
P.randTrueFalseProb = 0.5;

%% -------------------- Start / Instruction Page --------------------------
P.start.waitForKey = true;
P.start.message    = 'Press any key to start';

%% -------------------- Photodiode ----------------------------------------
P.photodiode.enabled = true;
P.photodiode.rectPix = [0 0 120 120];
P.photodiode.flipDur = 0.016;
P.photodiode.mode    = 'steady';
P.photodiode.scope   = 'digits';
P.photodiode.color   = 255;

%% -------------------- Response device -----------------------------------
P.input.responseBox = false;
P.input.keyboardOK  = true;
P.input.useKeyboard = [];

%% -------------------- Audio ---------------------------------------------
P.audio.fs              = 16000;
P.audio.nchannels       = 1;
P.audio.bits            = 16;
P.audio.maxsecs         = 4;
P.audio.threshold       = 0.15;
P.audio.silenceDuration = 0.3;
P.audio.postSilence     = 0.5;
P.audio.chunkSec        = 0.01;
P.audio.noiseSecs       = 3;
P.audio.speechSecs      = 5;
P.audio.noiseMultiplier = 5;

%% -------------------- Screen --------------------------------------------
try
    whichScreen = max(Screen('Screens'));
catch
    whichScreen = 0;
end

P.screen.whichScreen      = whichScreen;
P.screen.fullscreen       = true;
P.screen.skipSync         = 0;
P.screen.bgColor          = 0;
P.screen.textColor        = 255;
P.screen.fontName         = 'Arial';
P.screen.textSize         = 140;
P.screen.strictFullscreen = true;

%% -------------------- Trigger / HW -------------------------------------
P.trigger.mode    = 'TriggerBox';
P.trigger.pulseMs = 40;

%% -------------------- EEG system ----------------------------------------
P.eeg_system = 'brainproducts';   % 'brainproducts' | 'biosemi' | 'none'

%% -------------------- Eye tracker defaults ------------------------------
% P.eyetracker.system is the single field runner scripts and
% eyetracker_manager read to decide which hardware to use.
% Default is 'none'; the UI dialog below lets the user override this.
P.eyetracker.system = 'none';     % 'eyelink' | 'pupil_labs' | 'none'

% EyeLink parameters (used when P.eyetracker.system == 'eyelink')
P.eyelink.enable       = false;
P.eyelink.ip           = '100.1.1.1';
P.eyelink.sampleRateHz = 1000;
P.eyelink.calibrate    = true;
P.eyelink.calType      = 'HV9';

% Pupil Labs Neon parameters (used when P.eyetracker.system == 'pupil_labs')
P.neon.enable  = false;
P.neon.host    = 'neon.local';    % mDNS hostname
P.neon.ip      = '192.168.8.145'; % static IP fallback
P.neon.port    = 8080;
P.neon.recName = '';              % built after UI confirms subjectID/block

%% -------------------- Mock flags (base) ---------------------------------
P.mock.screen      = false;
P.mock.triggerbox  = true;        % safe default; overridden by profile below
P.mock.eyelink     = true;
P.mock.responsebox = true;

%% ================== UI dialog ===========================================
% Runs here so the user's confirmed choices drive the profile switch below.
% All hardware defaults must be defined above before this point so the
% dialog can display sensible values.
[P, confirmed] = get_task_info_ui(P);
if ~confirmed
    error('------- User cancelled experiment setup.');
end

% Re-read runProfile from P in case the user changed it in the UI
runProfile = lower(char(P.runProfile));

%% ================== Profile switch ======================================
switch runProfile

    case 'test'
        P.screen.fullscreen       = false;
        P.screen.skipSync         = 2;
        P.screen.strictFullscreen = false;
        P.nBlocks                 = 1;
        P.nTrials                 = 1;
        P.mock.triggerbox         = true;
        P.mock.eyelink            = true;
        P.mock.responsebox        = true;
        P.photodiode.enabled      = true;

    case 'eeg'
        P.screen.fullscreen       = true;
        P.screen.skipSync         = 0;
        P.screen.strictFullscreen = true;
        P.mock.triggerbox         = false;
        P.mock.eyelink            = true;
        P.mock.responsebox        = true;
        P.trigger.mode            = 'TriggerBox';
        P.trigger.pulseMs         = 40;
        P.trigger.comPort         = 'COM9';
        P.trigger.serial.baudBP   = 2000000;
        P.trigger.serial.baudBS   = 115200;
        P.trigger.idleLevel       = uint8(0);
        P.trigger.resetLevel      = 255;
        P.trigger.minGapSec       = 0.010;
        P.photodiode.enabled      = true;

    case 'eyetracker'
        P.screen.fullscreen       = true;
        P.screen.skipSync         = 0;
        P.screen.strictFullscreen = true;
        P.mock.triggerbox         = true;
        P.mock.eyelink            = false;
        P.mock.responsebox        = true;
        P.photodiode.enabled      = true;

    case 'fullsetup'
        P.screen.fullscreen       = true;
        P.screen.skipSync         = 0;
        P.screen.strictFullscreen = true;
        P.mock.triggerbox         = false;
        P.mock.eyelink            = false;
        P.mock.responsebox        = true;
        P.trigger.mode            = 'TriggerBox';
        P.trigger.pulseMs         = 40;
        P.trigger.comPort         = 'COM9';
        P.trigger.serial.baudBP   = 2000000;
        P.trigger.serial.baudBS   = 115200;
        P.trigger.idleLevel       = uint8(0);
        P.trigger.resetLevel      = 255;
        P.trigger.minGapSec       = 0.010;
        P.photodiode.enabled      = true;
end

%% -------------------- Eye tracker enable flags --------------------------
% Derived automatically from P.eyetracker.system chosen in the UI.
% Runner scripts should read P.eyetracker.system directly;
% these flags exist for backward compatibility only.
switch lower(char(P.eyetracker.system))
    case 'eyelink'
        P.eyelink.enable = true;
        P.neon.enable    = false;
    case 'pupil_labs'
        P.eyelink.enable = false;
        P.neon.enable    = true;
    case 'none'
        P.eyelink.enable = false;
        P.neon.enable    = false;
end

%% -------------------- Keyboard vs response box --------------------------
if P.input.responseBox
    P.input.useKeyboard = false;
else
    if isempty(P.input.useKeyboard)
        P.input.useKeyboard = true;
    end
end

%% -------------------- Distractor visuals --------------------------------
P.distractor.exprYOffset  = -30;
P.distractor.instrYOffset = 120;

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
P.probe.displayStyle       = 'question';
P.probe.postprobe_range    = [1.0, 1.5];

%% -------------------- Text before start ---------------------------------
P.Text.taskCondition = 'Same Order';

%% -------------------- Per-machine tweaks --------------------------------
host              = getenv('COMPUTERNAME');
P.screen.hostname = host;

switch upper(host)
    case 'CNS-DD3XM3V64'                % dev PC
        P.screen.skipSync         = 2;
        P.screen.fullscreen       = true;
        P.screen.strictFullscreen = false;
        try
            P.screen.whichScreen  = max(Screen('Screens'));
        catch
            P.screen.whichScreen  = 0;
        end

    otherwise                           % stim PC
        P.screen.skipSync         = 0;
        P.screen.fullscreen       = true;
        P.screen.strictFullscreen = true;
        P.mock.triggerbox         = false;
end

%% -------------------- File paths ----------------------------------------
path_save_CSV = [char(P.runProfile), '\', P.subjectID, '\', P.condition, '\', P.block];

P.saveDir       = fullfile(pwd, 'output', path_save_CSV);
P.audio.saveDir = fullfile(pwd, 'output', path_save_CSV, 'AudioFiles');

if ~exist(P.saveDir,       'dir'), mkdir(P.saveDir);       end
if ~exist(P.audio.saveDir, 'dir'), mkdir(P.audio.saveDir); end

P.csvFile = sprintf('%s_%s_wm_%s_events.csv', ...
    P.subjectID, P.block, P.condition);

% EyeLink: tracker always opens 'tmp', received as tmp.edf, renamed locally
P.edfFile = sprintf('%s_%s_wm_%s_eyedata.edf', ...
    P.subjectID, P.block, P.condition);

% Pupil Labs: recording name built here after UI has confirmed subjectID/block
P.neon.recName = sprintf('%s_%s_wm_%s_eyedata', ...
    P.subjectID, P.block, P.condition);

end