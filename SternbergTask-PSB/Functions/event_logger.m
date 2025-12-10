function L = event_logger(cmd, varargin)
% -------------------------------------------------------------------------
% EVENT_LOGGER
% CSV event logger with wall-clock timestamps and inter-event durations
%
% USAGE
%   L = event_logger('init', P, C)
%   event_logger('add',   L, eventName, code, t_on, ~, extra)
%   event_logger('close', L)
%
% FEATURES
%   - One CSV row per event.
%   - Each row repeats subject / condition / session / task_start_time
%     to makes analysis in MATLAB/Python/R much easier.
%   - 'duration_to_next' is filled when the *next* event arrives.
%     Last event (on 'close') gets duration_to_next = NaN.
%   - Accepts an optional "extra" struct for things like:
%       extra.value   -> value_shown
%       extra.entered -> entered_value
%       extra.rt      -> rt
%       extra.correct -> correct (0/1)
%       extra.keyName -> key_name
%       extra.note    -> note
%       extra.json    -> json blob (otherwise we jsonencode(extra))
%
% NOTE
%   - The task is expected to set L.block and L.trial before calling 'add'.
%   - This is designed to be called a lot, so the code stays simple.
% -------------------------------------------------------------------------

switch lower(cmd)

    % =====================================================================
    case 'init'
    % =====================================================================
        P = varargin{1};
        C = varargin{2}; % keep signature consistent, even if unused

        % ---- create logger struct ----
        L = struct();
        L.file_version = ['Alavie_G01_', P.screen.hostname];
        L.subject      = P.subjectID;
        L.condition    = P.condition;
        L.sessionID    = P.sessionID;

        % session timing anchors
        L.t0_abs  = GetSecs();  % monotonic start
        L.t0_wall = datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSSSSS');

        % screen info (can be updated later once S is available)
        try
            scr = P.screen.whichScreen;
        catch
            scr = -1;
        end
        L.screen_index = scr;
        L.ifi          = NaN;
        L.refresh_hz   = NaN;
        %         L.pd_used      = isfield(P,'photodiode') && ...
        %                          isfield(P.photodiode,'enabled') && ...
        %                          P.photodiode.enabled;
        L.pd_used      = double(isfield(P,'photodiode') && isfield(P.photodiode,'enabled') && P.photodiode.enabled);

        % ---- path & file ----
        outDir = P.saveDir;
        if ~exist(outDir,'dir'), mkdir(outDir); end
        outCSV = fullfile(outDir, P.csvFile);
        % Optional suffix
        suffix = '';
        if numel(varargin) >= 3 && ischar(varargin{3}) && ~isempty(varargin{3})
            suffix = ['_' varargin{3}];
            [~, name, ext] = fileparts(P.csvFile);
            outCSV = fullfile(outDir, [name suffix ext]);
            L.csv  = outCSV;
        else
            L.csv  = outCSV;
        end

        % open CSV for writing
        L.fid = fopen(outCSV, 'w', 'n', 'UTF-8');
        if L.fid < 0
            error('event_logger: Cannot open CSV file for writing: %s', outCSV);
        end

        % ---- write header ----
        hdr = [ ...
            "file_version,subject,condition,session,task_start_time," + ...
            "block,trial,phase,event_name,event_code,wall_clock,t_rel_sec,duration_to_next," + ...
            "rt,value_shown,entered_value,correct,key_name,device,note,json," + ...
            "screen_index,ifi,refresh_hz,pd_used" ];
        fprintf(L.fid, '%s\n', char(hdr));

        % pending row buffer (we only write a row once we know its duration)
        L.pending = [];

        % default device (keyboard vs response box)
        if isfield(P,'input') && isfield(P.input,'useKeyboard')
            L.device = tern(P.input.useKeyboard, 'keyboard', 'responsebox');
        else
            L.device = 'keyboard';
        end

        % return logger to caller
        return;

    % =====================================================================
    case 'add'
    % =====================================================================
        L = varargin{1};
        if ischar(L)
            error('Pass the logger struct, not the filename.');
        end

        eventName = varargin{2};
        code      = varargin{3};
        t_on      = varargin{4};   % GetSecs timestamp
        extra     = struct();

        % extra fields (value, entered, rt, note, etc.)
        if numel(varargin) >= 6 && ~isempty(varargin{6})
            extra = varargin{6};
        end

        % ---- build base row ----
        row = base_row(L, eventName, code, t_on);
        row.phase = str(getfield_or(L, 'phase', ''));  % current task phase, if set
       
        % ---- map extra fields to CSV columns ----
        if isfield(extra,'rt'),        row.rt            = num(extra.rt);      end
        if isfield(extra,'value'),     row.value_shown   = str(extra.value);   end
        if isfield(extra,'entered'),   row.entered_value = str(extra.entered); end
        if isfield(extra,'correct'),   row.correct       = num(extra.correct); end
        if isfield(extra,'keyName'),   row.key_name      = str(extra.keyName); end
        if isfield(extra,'note'),      row.note          = str(extra.note);    end
        % if isfield(extra,'pd_used'),   row.pd_used       = num(extra.pd_used);   end

        % JSON: use provided, otherwise jsonencode(extra)
        if isfield(extra,'json')
            row.json = sanitize_json(extra.json);
        else
            try
                row.json = sanitize_json(jsonencode(extra));
            catch
                row.json = '';
            end
        end

        % ---- write previous pending row (now we know its duration) ----
        if ~isempty(L.pending)
            L.pending.duration_to_next = fmt_num(t_on - L.pending.t_abs);
            write_row(L.fid, L.pending);
        end

        % ---- keep current row as pending until next event ----
        row.t_abs = t_on;  % not written, only for duration math
        L.pending = row;

        % give updated L back to caller workspace (they keep L around)
        assignin('caller','L',L);
        return;

    % =====================================================================
    case 'close'
    % =====================================================================
        L = varargin{1};
        if ischar(L)
            return;
        end

        % flush last pending row with NaN duration
        if ~isempty(L.pending)
            L.pending.duration_to_next = 'NaN';
            write_row(L.fid, L.pending);
            L.pending = [];
        end

        % close file
        if isfield(L,'fid') && L.fid > 0
            fclose(L.fid);
            L.fid = -1;
        end
        return;

    % =====================================================================
    otherwise
        error('event_logger: Unknown command "%s".', cmd);
end
end

%% ========================================================================
% HELPER FUNCTIONS
%% ========================================================================

function row = base_row(L, eventName, code, t_on)
% Build a row struct with defaults + stable metadata

row = struct();

% ---- stable session metadata ----
row.file_version    = L.file_version;
row.subject         = str(L.subject);
row.condition       = str(L.condition);
row.session         = str(L.sessionID);
row.task_start_time = char(L.t0_wall);      % repeat on every row

% ---- trial counters (caller should have set L.block / L.trial) ----
row.block           = safe_int(getfield_or(L,'block', NaN));
row.trial           = safe_int(getfield_or(L,'trial', NaN));

% ---- event identity ----
row.event_name      = str(eventName);
row.event_code      = safe_int(code);

% ---- time fields ----
row.wall_clock      = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSSSSS'));
row.t_rel_sec       = fmt_num(t_on - L.t0_abs);  % relative to session start
row.duration_to_next= '';                        % filled by next event

% ---- response/content defaults ----
row.rt              = '';
row.value_shown     = '';
row.entered_value   = '';
row.correct         = '';
row.key_name        = '';
row.device          = str(getfield_or(L,'device',''));
row.note            = '';
row.json            = '';

% ---- environment ----
row.screen_index    = safe_int(getfield_or(L,'screen_index', NaN));
row.ifi             = fmt_num(getfield_or(L,'ifi', NaN));
row.refresh_hz      = fmt_num(getfield_or(L,'refresh_hz', NaN));
row.pd_used         = safe_int(getfield_or(L,'pd_used', NaN));
end


function write_row(fid, row)
% Write a row struct as a CSV line in a fixed column order.

cols = { ...
    row.file_version, ...
    row.subject, ...
    row.condition, ...
    row.session, ...
    row.task_start_time, ...
    numstr(row.block), ...
    numstr(row.trial), ...
    csvsafe(getfield_or(row,'phase','')), ...
    csvsafe(row.event_name), ...
    numstr(row.event_code), ...
    row.wall_clock, ...
    row.t_rel_sec, ...
    row.duration_to_next, ...
    fmt_num(getfield_or(row,'rt', '')), ...
    csvsafe(row.value_shown), ...
    csvsafe(row.entered_value), ...
    numstr(row.correct), ...
    csvsafe(row.key_name), ...
    csvsafe(row.device), ...
    csvsafe(row.note), ...
    csvsafe(row.json), ...
    numstr(row.screen_index), ...
    getfield_or(row,'ifi',''), ...
    getfield_or(row,'refresh_hz',''), ...
    numstr(row.pd_used) ...
    };

line = strjoin(cols, ',');
fprintf(fid, '%s\n', line);
end


function s = csvsafe(x)
% Wrap in quotes if there are commas, quotes, or newlines.
s = str(x);
if any(s == '"') || any(s == ',') || any(s == char(10)) || any(s == char(13))
    s = strrep(s, '"', '""');  % escape existing quotes
    s = ['"' s '"'];
end
end


function s = str(x)
% Convert scalar/string/char/numeric/logical to char safely.
if ischar(x)
    s = x;
elseif isstring(x)
    s = char(x);
elseif isnumeric(x) && isscalar(x)
    if isnan(x)
        s = 'NaN';
    else
        s = num2str(x);
    end
elseif islogical(x) && isscalar(x)
    s = char(string(double(x)));
else
    try
        s = char(string(x));
    catch
        s = '';
    end
end
end


function n = num(x)
% Return numeric scalar or NaN.
if isnumeric(x) && isscalar(x)
    n = x;
elseif islogical(x) && isscalar(x)
    n = double(x);
else
    n = NaN;
end
end


function s = fmt_num(x)
% Format numeric for CSV with 6 decimals, preserving NaN.
if isnumeric(x) && isscalar(x)
    if isnan(x)
        s = 'NaN';
    else
        s = sprintf('%.6f', x);
    end
else
    s = '';
end
end


function v = getfield_or(S, f, defaultVal)
% get S.f if present, else defaultVal
if isstruct(S) && isfield(S,f)
    v = S.(f);
else
    v = defaultVal;
end
end


function y = safe_int(x)
% round numeric scalar, keep NaN if NaN
if isnumeric(x) && isscalar(x)
    if isnan(x)
        y = NaN;
    else
        y = round(x);
    end
else
    y = NaN;
end
end


function j = sanitize_json(jin)
% Ensure json is char and won't break CSV.
try
    if isstring(jin), jin = char(jin); end
    if ~ischar(jin)
        jin = jsonencode(jin);
    end
    j = jin;
catch
    j = '';
end
end


function out = tern(c, a, b)
% Simple ternary helper
if c
    out = a;
else
    out = b;
end
end


function s = numstr(x)
% NUMSTR  Safe integer-to-string for CSV fields.
% numbers -> rounded integer text
% NaN     -> 'NaN'
% empty   -> ''
% char/string passthrough

if isempty(x)
    s = '';
    return;
end

if isnumeric(x) && isscalar(x)
    if isnan(x)
        s = 'NaN';
    else
        s = sprintf('%d', round(x));
    end
elseif islogical(x) && isscalar(x)
    s = sprintf('%d', x ~= 0);
elseif isstring(x)
    s = char(x);
elseif ischar(x)
    s = x;
else
    % last resort
    try
        s = char(string(x));
    catch
        s = '';
    end
end
end

% -------------------------------------------------------------------------
% Summary of the flow:
%   1) 'init': create struct, open CSV, write header.
%   2) 'add' : build row, fill extra, write previous pending (with duration),
%              keep current as pending.
%   3) 'close': flush last pending (duration_to_next = NaN), close file.
% -------------------------------------------------------------------------
