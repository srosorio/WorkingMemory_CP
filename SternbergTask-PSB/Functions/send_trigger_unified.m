function send_trigger_unified(mode, P, code, pulseMs, eeg_system)
% -------------------------------------------------------------------------
% Unified Trigger Function (BrainProducts TriggerBox OR BioSemi)
% -------------------------------------------------------------------------
% USAGE:
%   send_trigger_unified('init',  P, [], [], eeg_system)
%   send_trigger_unified('send',  P, code, pulseMs, eeg_system)
%   send_trigger_unified('set',   P, byte, [], eeg_system)
%   send_trigger_unified('close', P, [], [], eeg_system)
%
% eeg_system:
%   'BrainProducts'  → use IOPort-based TriggerBox code (original #1)
%   'BioSemi'        → use MATLAB serial() code (original #2)
%
% Preserves:
%   - persistent TB for each system
%   - idle/reset levels (BrainProducts only)
%   - mock mode support
%   - minGap timing
%   - pulse shaping logic
%
% -------------------------------------------------------------------------

persistent TB_BP   % BrainProducts state
persistent TB_BS   % BioSemi state

if nargin < 4 || isempty(pulseMs)
    pulseMs = P.trigger.pulseMs;
end

if ismember(P.runProfile, 'test')
    fprintf('[TEST - No Trigger]\n');
    return;
end

% =========================================================================
% CHOOSE SYSTEM
% =========================================================================
switch lower(eeg_system)
    case {'brainproducts'}
        SYSTEM = 'BP';
    case {'biosemi'}
        SYSTEM = 'BS';
    otherwise
        error('Unknown eeg_system: %s (expected BrainProducts or BioSemi)', eeg_system);
end

% =========================================================================
% BRANCH TO EACH IMPLEMENTATION
% =========================================================================

switch SYSTEM
% #########################################################################
% ### BRAIN PRODUCTS (TriggerBox / IOPort version)
% #########################################################################
case 'BP'

    % Make persistent available locally
    TB = TB_BP;

    switch lower(mode)

        case 'init'
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
                'fh',        [], ...
                'isOpen',    false, ...
                'mock',      false, ...
                'idle',      idleLevel, ...
                'reset',     resetLevel, ...
                'minGap',    minGap, ...
                'lastWriteT',0);

            if isfield(P,'mock') && isfield(P.mock,'triggerbox') && P.mock.triggerbox
                TB.mock   = true;
                TB.isOpen = true;
                fprintf('[MOCK TriggerBox] init OK.\n');
                TB_BP = TB;
                return;
            end

            opts = sprintf(['BaudRate=%d Parity=None DataBits=8 StopBits=1 ' ...
                'DTR=0 RTS=0 ReceiveTimeout=0.01 SendTimeout=0.01 FlowControl=None'], baud);

            try
                [fh, errmsg] = IOPort('OpenSerialPort', port, opts);
                if ~isempty(errmsg), error('%s', errmsg); end

                TB.fh     = fh;
                TB.isOpen = true;

                IOPort('Write', TB.fh, TB.idle, 1);
                IOPort('Flush', TB.fh);

                fprintf('[TriggerBox] Opened %s @%d baud.\n', port, baud);

            catch ME
                TB = [];
                error('TriggerBox open error: %s', ME.message);
            end

        case 'send'
            if isempty(TB) || ~TB.isOpen
                warning('TriggerBox not initialized.');
                return;
            end

            if TB.mock
                fprintf('[MOCK TriggerBox] code=%d pulseMs=%d\n',code,pulseMs);
                return;
            end

            nowT = GetSecs();
            if nowT - TB.lastWriteT < TB.minGap
                WaitSecs(TB.minGap - (nowT - TB.lastWriteT));
            end

            byte = uint8(bitand(code,255));
            IOPort('Write', TB.fh, byte, 1);

            if pulseMs > 0
                WaitSecs(pulseMs/1000);
            end

            IOPort('Write', TB.fh, TB.idle, 1);
            TB.lastWriteT = GetSecs();

        case 'set'
            if isempty(TB) || ~TB.isOpen
                warning('TriggerBox not initialized.');
                return;
            end

            if TB.mock
                fprintf('[MOCK TriggerBox SET] byte=%d\n', code);
                return;
            end

            IOPort('Write', TB.fh, uint8(bitand(code,255)), 1);
            TB.lastWriteT = GetSecs();

        case 'close'
            if ~isempty(TB) && TB.isOpen && ~TB.mock
                try
                    IOPort('Write', TB.fh, TB.reset, 1);
                    WaitSecs(0.01);
                    IOPort('Close', TB.fh);
                catch
                end
            end
            TB = [];
            fprintf('[TriggerBox] closed.\n');

        otherwise
            error('Unknown mode %s', mode);
    end

    TB_BP = TB;   % save state back to persistent

% #########################################################################
% ### BIOSEMI (serial/fwrite version)
% #########################################################################
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
                TB.mock   = true;
                TB.isOpen = true;
                fprintf('[MOCK BioSemi] init OK.\n');
                TB_BS = TB;
                return;
            end

            try
                TB.fh = serial(port,'BaudRate',baud,'DataBits',8,...
                    'StopBits',1,'Parity','none','FlowControl','none');
                fopen(TB.fh);
                TB.isOpen = true;
                fprintf('[BioSemi] Opened %s @%d baud.\n', port, baud);
            catch ME
                TB = [];
                error('BioSemi open error: %s', ME.message);
            end

        case 'send'
            if isempty(TB) || ~TB.isOpen
                warning('BioSemi not initialized.');
                return;
            end

            if TB.mock
                fprintf('[MOCK BioSemi] code=%d pulseMs=%d\n',code,pulseMs);
                return;
            end

            nowT = GetSecs();
            if nowT - TB.lastWriteT < 0.01
                WaitSecs(0.01 - (nowT - TB.lastWriteT));
            end

            fwrite(TB.fh, uint8(bitand(code,255)));

            if pulseMs > 0
                WaitSecs(pulseMs/1000);
                fwrite(TB.fh, uint8(0));    % reset
            end

            TB.lastWriteT = GetSecs();

        case 'set'
            if TB.mock
                fprintf('[MOCK BioSemi SET] byte=%d\n', code);
                return;
            end

            fwrite(TB.fh, uint8(bitand(code,255)));
            TB.lastWriteT = GetSecs();

        case 'close'
            if ~isempty(TB) && TB.isOpen && ~TB.mock
                try
                    fclose(TB.fh);
                    delete(TB.fh);
                catch
                end
            end
            TB = [];
            fprintf('[BioSemi] closed.\n');

        otherwise
            error('Unknown mode %s', mode);
    end

    TB_BS = TB;  % save persistent state

end

end

% Helper
function v = getfield_def(S,f,d)
if isstruct(S) && isfield(S,f) && ~isempty(S.(f))
    v = S.(f);
else
    v = d;
end
end
