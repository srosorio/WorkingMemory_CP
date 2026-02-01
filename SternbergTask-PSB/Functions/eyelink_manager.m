function E = eyelink_manager(mode, P, window, E)
% this function manages all other PTB eyelink functions
% valid modes are:
%           'init', 'initialize,
%           'cal', 'calibration', 'calibrate'
%           'end', 'close', 'shutdown'

mode = lower(mode);

% Detect whether E was provided
E_provided = (nargin >= 4) && ~isempty(E);

if ~E_provided
    if strcmpi(mode, 'init')
        % OK: create E locally
        E = struct();
    else
        error('E must be provided for mode "%s"', mode);
    end
end

switch mode

    case {'init', 'initialize'}

        fprintf('Connecting to Eyelink...\n');

        if ~EyelinkInit()
            error('Eyelink Init failed. Check network cable and host PC.');
        end

        E.el = EyelinkInitDefaults(window);
        E.el.backgroundcolour = 0;   % black
        E.el.foregroundcolour = 255; % white
        E.didCal = false;
        E.recalKey    = 'r';
        E.continueKey = 'space';

        % Send display geometry to tracker + log it
        [winW, winH] = Screen('WindowSize', window);
        Eyelink('Command', 'screen_pixel_coords = 0 0 %d %d', winW-1, winH-1);
        Eyelink('Message', 'DISPLAY_COORDS 0 0 %d %d', winW-1, winH-1);

        % Calibration type (HV9 by default)
        Eyelink('Command', 'calibration_type = %s', P.eyelink.calType);

        fprintf('[Eyelink] Connected + geometry sent + calibration_type=%s\n', P.eyelink.calType);

        edf_file = P.edfFile;
        Eyelink('OpenFile', edf_file);
        Eyelink('Message', 'EDF_OPENED %s', edf_file);

        % log it into Eyelink EDF
        Eyelink('Message', 'SESSION_EYELINK_INIT_DONE');

    case {'cal', 'calibrate','calibration'}

        Eyelink('Command', 'record_status_message "Press ESC to continue experiment"');
        calMsg = sprintf('Press %s to recalibrate the eye tracker.', 'R');

        % Draw page
        Screen('FillRect', window, 0);
        DrawFormattedText(window, calMsg, 'center', 'center', 160);
        Screen('Flip', window);

        % wait for key to confirm beginning of calibration
        KbName('UnifyKeyNames');

        try
            % --- Key loop ---
            while true
                [down, ~, kc] = KbCheck;
                if down
                    k = KbName(find(kc,1));
                    if iscell(k), k = k{1}; end
                    k = lower(k);

                    if strcmp(k, E.recalKey)
                        EyelinkDoTrackerSetup(E.el);
                        E.didCal = true;
                        break;
                    elseif strcmp(k, E.continueKey)
                        break;
                    elseif strcmp(k, 'escape')
                        error('ESC_PRESSED');
                        
                    end
                end
            end
            KbReleaseWait;

        catch ME
            if strcmp(ME.message, 'ESC_PRESSED')
                fprintf('Experiment aborted by user (ESC).\n');

                % --- compact cleanup ---
                try, Eyelink('StopRecording'); end
                try, Eyelink('CloseFile'); end
                try, Eyelink('Shutdown'); end
                try, Screen('CloseAll'); end

                return
            else
                rethrow(ME)
            end
        end


        % exit set up mode and enter recording mode
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.05);
        Eyelink('StartRecording');
        Eyelink('WaitForModeReady', 500);
        Eyelink('Message', 'EYELINK_RECORDING_STARTED');

    case {'end','off','shutdown'}

        % log end of session and tell eyeling to stop recording
        Eyelink('Message', 'SESSION_END');
        Eyelink('StopRecording');
        Eyelink('CloseFile');

        % save edf file
        edfFullPath = P.saveDir;
        status = Eyelink('ReceiveFile', P.edfFile, edfFullPath, 1);
        fprintf('ReceiveFile status = %d\n', status);

        % shut down eyelink
        Eyelink('Shutdown');

    otherwise
        error('Unknown eyelink mode: %s', mode);

end

end
