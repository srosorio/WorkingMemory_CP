function send_trigger_unified(mode, P, code, pulseMs, E)
% -------------------------------------------------------------------------
% Unified Trigger Function (BrainProducts TriggerBox OR BioSemi)
% -------------------------------------------------------------------------
% USAGE:
%   send_trigger_unified('init',  P, [], [], E)
%   send_trigger_unified('send',  P, code, pulseMs, E)
%   send_trigger_unified('set',   P, byte, [], E)
%   send_trigger_unified('close', P, [], [], E)
%
% E is optional. If absent or empty, eye tracker messages are skipped.
% E is the struct returned by eyetracker_manager('init', ...).
%
% eeg_system is read from P.eeg_system:
%   'brainproducts'  → IOPort-based TriggerBox
%   'biosemi'        → MATLAB serial()
%
% -------------------------------------------------------------------------

persistent TB_BP   % BrainProducts state
persistent TB_BS   % BioSemi state

%% ---- Defaults ----------------------------------------------------------
if nargin < 4 || isempty(pulseMs)
    pulseMs = P.trigger.pulseMs;
end

% E is optional – safe default skips all eye tracker messages
if nargin < 5 || isempty(E)
    E = struct('system', 'none');
end

%% ---- Helper: should we send an eye tracker message? --------------------
% True only when a real eye tracker is connected and profile requires it.
sendET = ~strcmpi(E.system, 'none') && ...
    ismember(P.runProfile, {'fullSetup', 'eyetracker'});

%% ---- Test profile: skip everything -------------------------------------
if ismember(P.runProfile, {'test'})
    fprintf('[TEST - No Trigger]\n');
    return;
end

%% ======================================================================
if ~ismember(P.runProfile, {'test', 'eyetracker'})

    % Choose system
    switch lower(P.eeg_system)
        case 'brainproducts',  SYSTEM = 'BP';
        case 'biosemi',        SYSTEM = 'BS';
        otherwise
            error('Unknown eeg_system: %s (expected brainproducts or biosemi)', P.eeg_system);
    end

    switch SYSTEM

        % #################################################################
        % ### BRAIN PRODUCTS
        % #################################################################
        case 'BP'
            TB = TB_BP;
            switch lower(mode)

                case 'init'
                    P.trigger.comPort = 'COM5';
                    port = P.trigger.comPort;
                    if isfield(P,'trigger') && isfield(P.trigger,'serial') && isfield(P.trigger.serial,'baudBP')
                        baud = P.trigger.serial.baudBP;
                    else
                        baud = 2000000;
                    end

                    idleLevel  = uint8(getfield_def(P.trigger,'idleLevel',0));
                    resetLevel = uint8(getfield_def(P.trigger,'resetLevel',255));
                    minGap     = getfield_def(P.trigger,'minGapSec',0.010);

                    TB = struct( ...
                        'fh',[], 'isOpen',false, 'mock',false, ...
                        'idle',idleLevel, 'reset',resetLevel, ...
                        'minGap',minGap, 'lastWriteT',0);

                    if isfield(P,'mock') && isfield(P.mock,'triggerbox') && P.mock.triggerbox
                        TB.mock = true; TB.isOpen = true;
                        fprintf('[MOCK TriggerBox] init OK.\n');
                        TB_BP = TB; return;
                    end

                    opts = sprintf(['BaudRate=%d Parity=None DataBits=8 StopBits=1 ' ...
                        'DTR=0 RTS=0 ReceiveTimeout=0.01 SendTimeout=0.01 FlowControl=None'], baud);
                    try
                        [fh, errmsg] = IOPort('OpenSerialPort', port, opts);
                        if ~isempty(errmsg), error('%s', errmsg); end
                        TB.fh = fh; TB.isOpen = true;
                        IOPort('Write', TB.fh, TB.idle, 1);
                        IOPort('Flush', TB.fh);
                        fprintf('[BrainProducts] Opened %s @%d baud.\n', port, baud);
                    catch ME
                        TB = []; error('BrainProducts open error: %s', ME.message);
                    end

                case 'send'
                    if isempty(TB) || ~TB.isOpen
                        warning('BrainProducts not initialized.'); return;
                    end
                    if TB.mock
                        fprintf('[MOCK BrainProducts] code=%d pulseMs=%d\n', code, pulseMs); return;
                    end

                    nowT = GetSecs();
                    if nowT - TB.lastWriteT < TB.minGap
                        WaitSecs(TB.minGap - (nowT - TB.lastWriteT));
                    end
                    byte = uint8(bitand(code, 255));
                    IOPort('Write', TB.fh, byte, 1);
                    if pulseMs > 0, WaitSecs(pulseMs/1000); end
                    IOPort('Write', TB.fh, TB.idle, 1);
                    TB.lastWriteT = GetSecs();

                    % Eye tracker message
                    if sendET
                        et_send_message(E, code);
                    end

                case 'set'
                    if isempty(TB) || ~TB.isOpen
                        warning('BrainProducts not initialized.'); return;
                    end
                    if TB.mock
                        fprintf('[MOCK BrainProducts SET] byte=%d\n', code); return;
                    end
                    IOPort('Write', TB.fh, uint8(bitand(code,255)), 1);
                    TB.lastWriteT = GetSecs();

                    % Eye tracker message
                    if sendET
                        et_send_message(E, code);
                    end

                case 'close'
                    if ~isempty(TB) && TB.isOpen && ~TB.mock
                        try
                            IOPort('Write', TB.fh, TB.reset, 1);
                            WaitSecs(0.01);
                            IOPort('Close', TB.fh);
                        catch, end
                    end
                    TB = [];
                    fprintf('[BrainProducts] closed.\n');

                otherwise
                    error('Unknown mode: %s', mode);
            end
            TB_BP = TB;

            % #################################################################
            % ### BIOSEMI
            % #################################################################
        case 'BS'
            TB = TB_BS;
            switch lower(mode)

                case 'init'
                    port = P.trigger.comPort;
                    if isfield(P,'trigger') && isfield(P.trigger,'serial') && isfield(P.trigger.serial,'baudBS')
                        baud = P.trigger.serial.baudBS;
                    else
                        baud = 2000000;
                    end

                    TB = struct('fh',[], 'isOpen',false, 'mock',false, 'lastWriteT',0);

                    if isfield(P,'mock') && isfield(P.mock,'triggerbox') && P.mock.triggerbox
                        TB.mock = true; TB.isOpen = true;
                        fprintf('[MOCK BioSemi] init OK.\n');
                        TB_BS = TB; return;
                    end

                    try
                        TB.fh = serial(port, 'BaudRate',baud, 'DataBits',8, ...
                            'StopBits',1, 'Parity','none', 'FlowControl','none');
                        fopen(TB.fh);
                        TB.isOpen = true;
                        fprintf('[BioSemi] Serial opened %s @%d baud\n', port, baud);
                    catch ME
                        TB = []; error('[BioSemi] Failed to open %s: %s', port, ME.message);
                    end

                case 'send'
                    if isempty(TB) || ~TB.isOpen
                        warning('[BioSemi] Not initialized.'); return;
                    end
                    if TB.mock
                        fprintf('[MOCK BioSemi] code=%d pulseMs=%d\n', code, pulseMs); return;
                    end

                    nowT = GetSecs();
                    dt   = nowT - TB.lastWriteT;
                    if dt < 0.01, WaitSecs(0.01 - dt); end

                    fwrite(TB.fh, uint8(bitand(code,255)));
                    if pulseMs > 0
                        WaitSecs(pulseMs/1000);
                        fwrite(TB.fh, uint8(0));
                    end
                    TB.lastWriteT = GetSecs();

                    % Eye tracker message (skip internal codes 6,7,8)
                    if sendET && ~ismember(code, [6 7 8])
                        et_send_message(E, code);
                    end

                case 'set'
                    if isempty(TB) || ~TB.isOpen
                        warning('[BioSemi] Not initialized.'); return;
                    end
                    if TB.mock
                        fprintf('[MOCK BioSemi SET] byte=%d\n', code); return;
                    end
                    fwrite(TB.fh, uint8(bitand(code,255)));
                    TB.lastWriteT = GetSecs();

                    % Eye tracker message
                    if sendET
                        et_send_message(E, code);
                    end

                case 'close'
                    if ~isempty(TB) && TB.isOpen && ~TB.mock
                        try, fclose(TB.fh); delete(TB.fh); catch, end
                    end
                    TB = [];
                    fprintf('[BioSemi] Serial closed.\n');

                otherwise
                    error('send_trigger: unknown mode "%s"', mode);
            end
            TB_BS = TB;
    end

elseif ismember(P.runProfile, {'eyetracker'})
    % Eyetracker-only profile: no hardware trigger, just eye tracker message
    switch lower(mode)
        case 'send'
            if sendET && ~ismember(code, [6 7 8])
                et_send_message(E, code);
            end
    end

else
    fprintf('[TEST - no Trigger]\n');
end


% =========================================================================
%  PRIVATE HELPERS
% =========================================================================

    function et_send_message(E, code)
        % Route an event message to the active eye tracker.
        % EyeLink: uses Eyelink('Message') – no E.device needed.
        % Pupil Labs: uses E.device.send_event().
        switch lower(E.system)
            case 'eyelink'
                Eyelink('Message', '%d', code);
            case 'pupil_labs'
                try
                    E.device.send_event(num2str(code));
                catch ME
                    warning('[EyeTracker] send_event failed (code=%d): %s', code, ME.message);
                end
            case 'none'
                % silent no-op
        end
    end

    function v = getfield_def(S, f, d)
        if isstruct(S) && isfield(S,f) && ~isempty(S.(f))
            v = S.(f);
        else
            v = d;
        end
    end

end