function Run_Sternberg_WM_Task_AudResp_With_Control()
%*************************************************************************
% Alavie Mirfathollahi - 2025 -  Sternberg WM task
%*************************************************************************
%
% Visual sequence per trial:
%   1) Fix1baseline: [3.0, 3.5](jitter)
%   2) Digits:       [Digit 0.5s + Post-digit Fix (jitter)] x P.numDigits
%   3) Distractor:   (True/False) 4s
%   4) Fixation after distractor: [3, 3.5](jitter)
%   5) PROBE:        up to 100 sec
%
% All visual ON events are drawn via markEvent(...) with a redrawFcn
% so that screen flip, photodiode, and trigger are on the same frame.
%
% REQUIRED helper functions (must be on path):
%   - make_params
%   - choose_input_mode (if used inside make_params)
%   - make_event_codes
%   - event_logger
%   - send_trigger_unified
%   - open_ptb_screen
%   - wait_for_start
%   - redraw_* helpers (fixation, blank, digit, distractor, probe, ...)
%   - get_tf_response
%   - generate_distractor
%   - get_single_digit
%   - plus other function used inside of these
%
% Notes:
%   - This version keeps the digit recall at the center.
%   - Small sync fixes for triggers / photodiode.
%   - Main experiment logic is unchanged; only organization and comments added.
%
% -------------------------------------------------------------------------

try
    %% --------------------------------------------------------------------
    % 0) RNG safe init
    %% --------------------------------------------------------------------
    try
        rng('shuffle');
    catch
        rng('shuffle','twister');
    end

    %% --------------------------------------------------------------------
    % 1) Init: params, event codes, logger, triggeGUIr
    %% --------------------------------------------------------------------
    P = make_params('eeg','OFFmed_OFFstim','S01');                         % can change subject/session here (also in the UI)
    C = make_event_codes();
    L = event_logger('init', P, C);
    
    %  Run mic test code and automatic threshold detection
    threshold = test_mic_response(P);

    % triggerbox init (start of session)
    send_trigger_biosemi('init', P);

    % initalize PsychPortAudio
    pahandle = initialize_ptb_sound(P.audio.fs, P.audio.nchannels, P.audio.maxsecs);

    % --- basic sanity checks on code arrays
    assert(numel(C.DIGIT_ON_IDX)        >= P.numDigits,        'Codes: DIGIT_ON_IDX too short');
    assert(numel(C.DIGIT_OFF_IDX)       >= P.numDigits,        'Codes: DIGIT_OFF_IDX too short');
    assert(numel(C.POSTDIG_FIX_OFF_IDX) >= P.numDigits,        'Codes: POSTDIG_FIX_OFF_IDX too short');
    assert(numel(C.DIGIT_RECALL_LINE)   >= P.probe_max_digits, 'Codes: DIGIT_RECALL_LINE too short');
    assert(numel(C.DIGIT_RECALL_INPUT)  >= P.probe_max_digits, 'Codes: DIGIT_RECALL_INPUT too short');

    %% --------------------------------------------------------------------
    % 2) Open PTB screen
    %% --------------------------------------------------------------------
    S = open_ptb_screen(P);
    L.ifi        = S.ifi;
    L.refresh_hz = 1 / S.ifi;

    %% --------------------------------------------------------------------
    % 2.1) Gec Microphone threshold
    %% --------------------------------------------------------------------
    P.audio.threshold = threshold;
    
    %% --------------------------------------------------------------------
    % 3) Initialize eyelink (if needed)
    %% --------------------------------------------------------------------
    if ismember(P.runProfile, {'eyetracker','both'})
        E = eyelink_manager('init', P, S.win);
    end

    %% --------------------------------------------------------------------
    % 4) MAIN LOOP: blocks × trials
    %% --------------------------------------------------------------------
    nBlocks = P.nBlocks;
    nTrials = P.nTrials;

    for b = 1:nBlocks
        L.block = b;
        
        % do eyelink calibration only at block 1 for now
        if b==1 && ismember(P.runProfile,{'eyetracker','both'})
            E = eyelink_manager('calibrate', P, S.win, E);
        end

        % ----- block start -----
        event_logger('add', L, 'BLOCK_START', C.BLOCK_START, GetSecs(), 0, struct());
        if ~P.mock.triggerbox
            send_trigger_biosemi('send', P, C.BLOCK_START, P.trigger.pulseMs);
        end

        % =========================================================
        % PRE-BLOCK 10-DIGIT WARM-UP
        % =========================================================
        L.phase       = 'reading';
        L.trial       = 0;   % warm-up digits get "trial 0"
        entered       = "";                         % what subject entered so far
        % visibleSlots  = 1;                          % how many recall "places" are visible
          tProbeStart   = GetSecs();
        tDeadline     = tProbeStart + P.probe_max_total;

        Text_to_show_at_the_start = ['PART 1: Read aloud', '\n\n', 'Press any key to start'];

        % Show start page using markEvent (so PD + trigger are aligned)
        [~, L] = markEvent(P, L, S, C.START_PAGE_ON, 'START_PAGE_ON', struct(), ...
            @(w) DrawFormattedText(w, Text_to_show_at_the_start, 'center', 'center', P.screen.textColor));

        % Wait for experimenter/subject to press start
        wait_for_start(P, S, L, C, Text_to_show_at_the_start);

        % mark keypress
        if ~P.mock.triggerbox
            send_trigger_biosemi('send', P, C.START_KEYPRESS, P.trigger.pulseMs);
        end

        % quick sanity pulse (if trigger is connected)
        try
            send_trigger_biosemi('send', P, C.SANITY_PULSE, 10);
        catch ME
            fprintf('[Trigger sanity pulse failed] %s\n', ME.message);
            error
        end

        event_logger('add', L, 'CONTROL_START',  C.DIGITCOUNT_START,  GetSecs(), 0, struct());
        if ~P.mock.triggerbox
            send_trigger_biosemi('send', P, C.DIGITCOUNT_START, P.trigger.pulseMs);
        end

        % now start with the digits
        for k = 1:P.probe_max_count

            d = P.digitPool(randi(numel(P.digitPool)));
            % --- DIGIT k ON ---
            [~, L] = markEvent(P, L, S, C.DIGIT_READING_ON_IDX(k), sprintf('DIGIT_READ%d_ON', k), ...
                struct('value', d, 'note', sprintf('digit#%d shown',k)), ...
                @(w) redraw_digit_frame(w, P, S, d));

            % 1) wait for user to enter a single digit (with deadline)
            R = get_single_digit_vocal(tDeadline, P, L, k, pahandle);
            if R.quit
                error('User pressed ESCAPE during PROBE.');
            end
            if ~R.madeResponse
                % timeout in probe
                event_logger('add', L, 'PROBE_TIMEOUT', C.PROBE_TIMEOUT, GetSecs(), 0, ...
                    struct('note', sprintf('digits_entered=%s', entered)));
                break;
            end

            % 2) log this digit
            entered = entered + string(R.digit);
            event_logger('add', L, sprintf('PROBE_COUNT_OK_%d', k), C.PROBE_DIGIT_OK, R.tPress, 0, ...
                struct('value', sprintf('slot#%d', k), 'entered', R.digit, ...
                'rt', R.tPress - tProbeStart, 'note', sprintf('probe_digit#%d', k)));

            % 3) trigger for this digit
            send_trigger_biosemi('send', P, C.COUNT_READ_ALOUD(k), P.trigger.pulseMs);

            % 4) after entry: clear "?" or update display
            if strcmpi(P.probe.displayStyle, 'question')
                % --- DIGIT k OFF -> fixation ---
                [t_fix_on, L] = markEvent(P, L, S, C.DIGIT_READING_OFF_IDX(k), sprintf('DIGIT_READ%d_OFF', k), ...
                    struct('value', d, 'note', sprintf('digit#%d off',k)), ...
                    @(w) redraw_fixation_frame(w, P, S));

                % add alias so CSV shows post-digit fixation explicitly
                event_logger('add', L, sprintf('POSTREAD_FIX%d_ON', k), C.POSTREAD_FIX_ON_IDX(k), ...
                    t_fix_on, 0, struct('note', sprintf('after digit#%d',k)));

                % hold fixation (jitter)
                if k < P.numCounts
                    WaitSecs(jitter(P.postDigitFix_range));
                else
                    WaitSecs(jitter(P.postDigitFix_last_range));
                end
                % --- fixation OFF ---
                [~, L] = markEvent(P, L, S, C.POSTREAD_FIX_OFF_IDX(k), sprintf('POSTREAD_FIX%d_OFF', k), ...
                    struct('note', sprintf('after digit#%d',k)), ...
                    @(w) redraw_blank_frame(w, P));
                Screen('Flip', S.win);   % PD OFF here
            end

            % 7) stop if total probe time is over
            if GetSecs() >= tDeadline
                break;
            end
        end

        event_logger('add', L, 'CONTROL_END',  C.DIGITCOUNT_END,  GetSecs(), 0, struct());
        if ~P.mock.triggerbox
            send_trigger_biosemi('send', P, C.DIGITCOUNT_END, P.trigger.pulseMs);
        end

        %% --------------------------------------------------------------------
        % 3) START PAGE (via markEvent → PD+trigger same frame)
        %% --------------------------------------------------------------------
        Text_to_show_at_the_start = ['Part 2: Memory', '\n\n', P.start.message];

        % Show start page using markEvent (so PD + trigger are aligned)
        [~, L] = markEvent(P, L, S, C.START_PAGE_ON, 'START_PAGE_ON', struct(), ...
            @(w) DrawFormattedText(w, Text_to_show_at_the_start, 'center', 'center', P.screen.textColor));

        % Wait for experimenter/subject to press start
         wait_for_start(P, S, L, C, Text_to_show_at_the_start);

        % mark keypress
        if ~P.mock.triggerbox
            send_trigger_biosemi('send', P, C.START_KEYPRESS, P.trigger.pulseMs);
        end

        % session start in logger
        event_logger('add', L, 'SESSION_START', C.SESSION_START, GetSecs(), 0, struct());

        % quick sanity pulse (if trigger is connected)
        try
            send_trigger_biosemi('send', P, C.SANITY_PULSE, 10);
        catch ME
            fprintf('[Trigger sanity pulse failed] %s\n', ME.message);
            error
        end

        for t = 1:nTrials
            L.trial = t;

            % ----- trial start -----
            event_logger('add', L, 'TRIAL_CHANGE', C.TRIAL_CHANGE, GetSecs(), 0, struct('note','trial transition'));
            event_logger('add', L, 'TRIAL_START',  C.TRIAL_START,  GetSecs(), 0, struct());
            if ~P.mock.triggerbox
                send_trigger_biosemi('send', P, C.TRIAL_START, P.trigger.pulseMs);
            end

            %% =========================================================
            % A) FIXATION (baseline)
            %% =========================================================
            L.phase = 'fix1';
            [~, L] = markEvent(P, L, S, C.FIX1_ON, 'FIX1_ON', ...
                struct(), @(w) redraw_fixation_frame(w, P, S));
            WaitSecs(jitter(P.fix1_range));
            [~, L] = markEvent(P, L, S, C.FIX1_OFF, 'FIX1_OFF', struct(), ...
                @(w) redraw_blank_frame(w, P));

            %% =========================================================
            % B) DIGIT PRESENTATION (5 digits or P.numDigits)
            %% =========================================================
            L.phase = 'digit';
            for k = 1:P.numDigits
                % choose digit from pool
                d = P.digitPool(randi(numel(P.digitPool)));

                % --- DIGIT k ON ---
                [~, L] = markEvent(P, L, S, C.DIGIT_ON_IDX(k), sprintf('DIGIT%d_ON', k), ...
                    struct('value', d, 'note', sprintf('digit#%d shown',k)), ...
                    @(w) redraw_digit_frame(w, P, S, d));

                WaitSecs(P.digit_dur);

                % --- DIGIT k OFF -> fixation ---
                [t_fix_on, L] = markEvent(P, L, S, C.DIGIT_OFF_IDX(k), sprintf('DIGIT%d_OFF', k), ...
                    struct('value', d, 'note', sprintf('digit#%d off',k)), ...
                    @(w) redraw_fixation_frame(w, P, S));

                % add alias so CSV shows post-digit fixation explicitly
                event_logger('add', L, sprintf('POSTDIG_FIX%d_ON', k), C.POSTDIG_FIX_ON_IDX(k), ...
                    t_fix_on, 0, struct('note', sprintf('after digit#%d',k)));

                % hold fixation (jitter)
                if k < P.numDigits
                    WaitSecs(jitter(P.postDigitFix_range));
                else
                    WaitSecs(jitter(P.postDigitFix_last_range));
                end

                % --- fixation OFF ---
                [~, L] = markEvent(P, L, S, C.POSTDIG_FIX_OFF_IDX(k), sprintf('POSTDIG_FIX%d_OFF', k), ...
                    struct('note', sprintf('after digit#%d',k)), ...
                    @(w) redraw_blank_frame(w, P));
            end

            %% =========================================================
            % C) DISTRACTOR
            %% =========================================================
            L.phase = 'distractor';
            D = generate_distractor(P);   % struct with: a,b,shownSum,trueSum,isCorrect,...

            % distractor ON (with value info logged)
            [t_dist_on, L] = markEvent(P, L, S, C.DISTRACTOR_ON, 'DISTRACTOR_ON', ...
                struct('value', sprintf('%d+%d=%d', D.a, D.b, D.shownSum), ...
                'isCorrectTruth', D.isCorrect, 'trueSum', D.trueSum), ...
                @(w) redraw_distractor_frame_aud(w, P, S, D));

            deadline = t_dist_on + P.distractor_window;
            Rtf      = get_tf_response_vocal(P, L, deadline, pahandle);  % subject responds T/F

            if Rtf.madeResponse
                % ---------- user responded ----------
                [respChar, respLabel] = tf_label(Rtf.isTrue);
                isCorrect = (Rtf.isTrue == D.isCorrect);

                extraAns = struct( ...
                    'value',    sprintf('%d+%d=%d', D.a, D.b, D.shownSum), ...
                    'entered',  respChar, ...
                    'rt',       Rtf.tPress - t_dist_on, ...
                    'correct',  double(isCorrect), ...
                    'note',     sprintf('key=%s (%s)', Rtf.keyName, respLabel), ...
                    'truth',    D.isCorrect, ...
                    'trueSum',  D.trueSum, ...
                    'shownSum', D.shownSum, ...
                    'a',        D.a, ...
                    'b',        D.b );

                % log distractor answer
                event_logger('add', L, 'DISTRACTOR_ANS', C.DISTRACTOR_ANS, Rtf.tPress, 0, extraAns);

                % also send trigger for distractor answer
                if ~P.mock.triggerbox
                    send_trigger_biosemi('send', P, C.DISTRACTOR_ANS, P.trigger.pulseMs);
                end

                % correctness flags
                if isCorrect
                    event_logger('add', L, 'ANS_CORRECT', C.ANS_CORRECT, Rtf.tPress, 0, struct());
                else
                    event_logger('add', L, 'ANS_WRONG',   C.ANS_WRONG,   Rtf.tPress, 0, struct());
                end

                % go to fixation immediately
                [t_fix2_on, L] = markEvent(P, L, S, C.DISTRACTOR_OFF, 'DISTRACTOR_OFF', struct(), ...
                    @(w) redraw_fixation_frame(w, P, S));
                event_logger('add', L, 'FIX2_ON', C.FIX2_ON, t_fix2_on, 0, struct('note','immediate after response'));

            else
                % ---------- no response until deadline ----------
                remaining = deadline - GetSecs();
                if remaining > 0
                    WaitSecs(remaining);
                end

                [t_fix2_on, L] = markEvent(P, L, S, C.DISTRACTOR_OFF, 'DISTRACTOR_OFF', struct(), ...
                    @(w) redraw_fixation_frame(w, P, S));
                event_logger('add', L, 'FIX2_ON', C.FIX2_ON, t_fix2_on, 0, struct('note','deadline reached'));
            end

            % fixation after distractor (jitter)
            L.phase = 'fix2';
            WaitSecs(jitter(P.fix_after_dist_range));

            [~, L] = markEvent(P, L, S, C.FIX2_OFF, 'FIX2_OFF', struct(), ...
                @(w) redraw_blank_frame(w, P));

            %% =========================================================
            % D) PROBE PHASE (NEW) /-\
            %     - supports 2 display styles:
            %           1) 'question' → show "?" each time, remove after entry
            %           2) line/slot  → old behavior, show entered digits
            %     - per-digit trigger is kept
            %     - PD-aligned via markEvent when "?" (or line) is shown
            %% =========================================================
            L.phase = 'probe';
            entered       = "";                         % what subject entered so far
            visibleSlots  = 1;                          % how many recall "places" are visible
            tProbeStart   = GetSecs();
            tDeadline     = tProbeStart + P.probe_max_total;

            % % --- black screen before recall (PD ON here) ---
            % [~, L] = markEvent(P, L, S, C.RECALL_BLACK_ON, 'RECALL_BLACK_ON', ...
            %     struct('note','probe black page'), @(w) redraw_blank_frame(w,P));

            % --- first prompt (either "?" or line style) ---
            if strcmpi(P.probe.displayStyle, 'question')
                % show a single "?" in center ----------
                [~, L] = markEvent(P, L, S, C.DIGIT_RECALL_LINE(1), 'DIGIT_RECALL_LINE_1', ...
                    struct('value',1,'note','first recall question'), ...
                    @(w) redraw_probe_question_only(w, P, S));
            else
                % old line style -----------------------
                [~, L] = markEvent(P, L, S, C.DIGIT_RECALL_LINE(1), 'DIGIT_RECALL_LINE_1', ...
                    struct('value',1,'note','first recall line visible'), ...
                    @(w) redraw_probe_slots_frame_centeredR_Gray(w, P, S, entered, visibleSlots, 0, 0));
            end

            % --- collect up to P.probe_max_digits digits ---
            for k = 1:P.probe_max_digits

                % 1) wait for user to enter a single digit (with deadline)
                R = get_single_digit_vocal(tDeadline, P, L, k, pahandle);
                if R.quit
                    error('User pressed ESCAPE during PROBE.');
                end
                if ~R.madeResponse
                    % timeout in probe
                    event_logger('add', L, 'PROBE_TIMEOUT', C.PROBE_TIMEOUT, GetSecs(), 0, ...
                        struct('note', sprintf('digits_entered=%s', entered)));
                    break;
                end

                % 2) log this digit
                entered = entered + string(R.digit);
                event_logger('add', L, sprintf('PROBE_DIGIT_OK_%d', k), C.PROBE_DIGIT_OK, R.tPress, 0, ...
                    struct('value', sprintf('slot#%d', k), 'entered', R.digit, ...
                    'rt', R.tPress - tProbeStart, 'note', sprintf('probe_digit#%d', k)));

                % 3) trigger for this digit
                send_trigger_biosemi('send', P, C.DIGIT_RECALL_INPUT(k), P.trigger.pulseMs);

                % 4) after entry: clear "?" or update display
                if strcmpi(P.probe.displayStyle, 'question')
                    % --- DIGIT k OFF -> fixation ---
                    [t_fix_on, L] = markEvent(P, L, S, C.DIGIT_OFF_IDX(k), sprintf('DIGIT%d_OFF', k), ...
                        struct('value', d, 'note', sprintf('digit#%d off',k)), ...
                        @(w) redraw_fixation_frame(w, P, S));

                    % add alias so CSV shows post-digit fixation explicitly
                    event_logger('add', L, sprintf('POSTDIG_FIX%d_ON', k), C.POSTDIG_FIX_ON_IDX(k), ...
                        t_fix_on, 0, struct('note', sprintf('after digit#%d',k)));

                    % hold fixation (jitter)
                    if k < P.numDigits
                        WaitSecs(jitter(P.postDigitFix_range));
                    else
                        WaitSecs(jitter(P.postDigitFix_last_range));
                    end
                    % --- fixation OFF ---
                    [~, L] = markEvent(P, L, S, C.POSTDIG_FIX_OFF_IDX(k), sprintf('POSTDIG_FIX%d_OFF', k), ...
                        struct('note', sprintf('after digit#%d',k)), ...
                        @(w) redraw_blank_frame(w, P));
                    Screen('Flip', S.win);   % PD OFF here
                else
                    % show all entered digits (line style)
                    redraw_probe_slots_frame_centeredR_Gray(S.win, P, S, entered, visibleSlots, 0, 0);
                    Screen('Flip', S.win);
                end

                % 5) if we still have time and slots, show the next prompt
                if k < P.probe_max_digits && GetSecs() < tDeadline
                    visibleSlots = visibleSlots + 1;

                    if strcmpi(P.probe.displayStyle, 'question')
                        % show "?" again (with markEvent → PD ON)
                        [~, L] = markEvent(P, L, S, C.DIGIT_RECALL_LINE(visibleSlots), ...
                            sprintf('DIGIT_RECALL_LINE_%d', visibleSlots), ...
                            struct('value', visibleSlots, 'note','next recall question'), ...
                            @(w) redraw_probe_question_only(w, P, S));
                    else
                        % old style, show next line
                        [~, L] = markEvent(P, L, S, C.DIGIT_RECALL_LINE(visibleSlots), ...
                            sprintf('DIGIT_RECALL_LINE_%d', visibleSlots), ...
                            struct('value', visibleSlots, 'note','new recall line shown'), ...
                            @(w) redraw_probe_slots_frame_centeredR_Gray(w, P, S, entered, visibleSlots, 0, 0));
                    end
                end

                % 6) stop if total probe time is over
                if GetSecs() >= tDeadline
                    break;
                end
            end

            % --- PROBE DONE ---
            if ismissing(entered) || strlength(entered) == 0
                enteredStr = '';
            else
                enteredStr = char(entered);
            end

            event_logger('add', L, 'PROBE_DONE', C.PROBE_DONE, GetSecs(), 0, ...
                struct('value', enteredStr, 'note', 'probe complete'));

            % -----------------------------------------------------------------
            % NOTE:
            % Below are older / alternative PROBE implementations from previous
            % iterations. Kept here intentionally for reference. Marked as LEGACY.
            % -----------------------------------------------------------------
            % (your long commented blocks stay here, unchanged)
            % -----------------------------------------------------------------

            %% =========================================================
            % E) TRIAL END
            %% =========================================================
            event_logger('add', L, 'TRIAL_END', C.TRIAL_END, GetSecs(), 0, struct());
            if ~P.mock.triggerbox
                send_trigger_biosemi('send', P, C.TRIAL_END, P.trigger.pulseMs);
            end

        end % trial loop

        %% -------------------------------------------------------------
        % BLOCK END
        %% -------------------------------------------------------------
        event_logger('add', L, 'BLOCK_END', C.BLOCK_END, GetSecs(), 0, struct());
        if ~P.mock.triggerbox
            send_trigger_biosemi('send', P, C.BLOCK_END,  P.trigger.pulseMs);
        end
    end % block loop

    %% --------------------------------------------------------------------
    % 5) CLEAN SHUTDOWN
    %% --------------------------------------------------------------------
    if isfield(S,'win') && ~isempty(S.win) && S.win~=0
        ShowCursor(S.win);
        Priority(0);
        sca;
    end

    event_logger('add', L, 'SESSION_END', C.SESSION_END, GetSecs(), 0, struct());
    event_logger('close', L);
    send_trigger_biosemi('close', P);
    if ismember(P.runProfile,{'eyetracker','both'})
        eyelink_manager('end', P, S.win, E);
    end

    fprintf('[OK] Step 5 complete. Check CSV for *_ON/OFF with stable visuals.\n');

catch ME
    % Error handling
    try, ShowCursor; Priority(0); sca; end
    try, event_logger('close', L); end
    try, send_trigger_biosemi('close', P); end
    try, Eyelink('StopRecording'); end
    try, Eyelink('CloseFile'); end
    try, Eyelink('Shutdown'); end
    try, Screen('CloseAll'); end
    rethrow(ME);
end
end

% Alavie
