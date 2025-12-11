%% =========================================================================
%% Working Memory – Sternberg Task
%  Alavie / Sergio
%  Project: WorkingMemory_CP
%  Description:
%     MATLAB–Psychtoolbox implementation of the Sternberg Working Memory task
%     for Parkinson's disease research. This version synchronizes with EEG 
%     (Brain Products) and other physiological devices.
% =========================================================================

clc;
clearvars;
close all;
Screen('CloseAll');
warning('off', 'all');
sca;                                                                      

%% -------------------------------------------------------------------------
%  Experiment Start-Up Instructions
% -------------------------------------------------------------------------
% (1) Start BrainVision Recorder FIRST
%     → Confirm the TriggerBox is detected and all connections are working.
%
% (2) Run this MATLAB script to launch the task.
%
% (3) During the session:
%     • A sanity pulse (trigger code = 1) is sent right after SESSION_START.
%     • Proper triggers are sent for each:
%         - DIGIT_ON / DIGIT_j69846OFF
%         - Distractor
%         - Fixation
%         - Recall period
%     • A photodiode flash occurs at every visual onset 
%       (for cross-checking stimulus timing with EEG).
%
% (4) After completion:
%     • The CSV log file (e.g., *_events.csv) will include timestamps 
%       matching each trigger and event type.
% -------------------------------------------------------------------------

%% Add Paths
% Add the folder containing custom functions 
currentFolder = pwd; 
addpath(fullfile(currentFolder, 'Functions'));

%% ---------------------------------------------------------------------*----
%  Optional: Trigger Test
% -------------------------------------------------------------------------
% Uncomment the lines below to run a trigger self-test before data collection.
%
% P = make_params('eeg', 'OFFmed_OFFstim', 'TEST_SUBJ');
% send_trigger_selftest(P);    % Sends pulses 10, 20, 40, 80 (visible in Recorder)
%
%% -------------------------------------------------------------------------
%  Run Main Experiment Script
% -------------------------------------------------------------------------
% Replace the script name below with the correct task version as needed.
Run_Sternberg_WM_Task_AudResp_With_Control();

%% End of Script (Alavie/Sergio)
% =========================================================================
