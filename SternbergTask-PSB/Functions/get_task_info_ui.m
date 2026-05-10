function [P, confirmed] = get_task_info_ui(P)
% -------------------------------------------------------------------------
% Alavie/Sergio - Sternberg WM task
%
% GET_TASK_INFO_UI - GUI to view and optionally modify experiment parameters
%
% Opens a simple UI to review and modify key fields in struct P
% (e.g., subjectID, condition, etc.) before running the experiment.
%
% Usage:
%   [P, confirmed] = get_task_info_ui(P)
%
% Notes:
%   - Supports nested fields (e.g., 'Text.taskCondition').
%   - Automatically displays P.runProfile if present.
%   - Enlarged window to prevent overlap of buttons and last fields.
%   - Eye tracker system selectable via dropdown (eyelink / pupil_labs / none).
% -------------------------------------------------------------------------

% -------- Editable fields --------
% Each entry is either:
%   - A plain string  → text edit box
%   - A cell {fieldName, {opt1, opt2, ...}}  → dropdown
editableFields = { ...
    'subjectID', ...
    'block', ...
    'condition', ...
    {'runProfile',    {'eeg','test','eyetracker','fullSetup'}}, ...
    {'eeg_system',    {'none','biosemi','brainproducts'}}, ...
    {'eyetracker_system', {'eyelink','pupil_labs','none'}}, ...  % → P.eyetracker.system
    'Text.taskCondition', ...
    'nTrials', ...
    'numDigits' ...
    };

% -------- Figure setup --------
figW = 520;
n    = numel(editableFields);
rowH = 30;
gap  = 10;
headerH = 60;
btnH    = 60;
figH    = headerH + n*(rowH+gap) + gap + btnH + 20;

fig = figure('Name','Experiment Setup',...
    'MenuBar','none','ToolBar','none','NumberTitle','off',...
    'Position',[600 200 figW figH],...
    'Resize','off','Color',[0.95 0.95 0.95]);

% -------- Header --------
uicontrol(fig,'Style','text',...
    'String','Experiment Parameters Review',...
    'FontSize',13,'FontWeight','bold',...
    'Position',[20 figH-50 figW-40 35],...
    'BackgroundColor',[0.95 0.95 0.95],...
    'HorizontalAlignment','center');

% -------- Column positions --------
labelX = 30;  editX = 220;
labelW = 180; editW = 270;
startY = figH - headerH - rowH;

% -------- Loop through fields --------
handles    = struct();
fieldMeta  = struct();   % store field name + options for each row

for i = 1:n
    entry = editableFields{i};

    % Parse entry
    if iscell(entry)
        fieldName = entry{1};
        options   = entry{2};
        isDropdown = true;
    else
        fieldName = entry;
        options   = {};
        isDropdown = false;
    end

    % Map UI field name → actual P path
    [pPath, labelStr] = field_to_ppath(fieldName);

    % Get current value from P
    try
        val = get_nested(P, pPath);
    catch
        val = '';
    end

    yPos = startY - (i-1)*(rowH+gap);

    % Label
    uicontrol(fig,'Style','text',...
        'String', sprintf('%s:', labelStr),...
        'Position',[labelX yPos labelW 22],...
        'HorizontalAlignment','right',...
        'BackgroundColor',[0.95 0.95 0.95],...
        'FontSize', 10);

    safeName = matlab.lang.makeValidName(fieldName);

    if isDropdown
        % Find index of current value in options list
        valStr = char(string(val));
        valIdx = find(strcmpi(options, valStr), 1);
        if isempty(valIdx), valIdx = 1; end

        handles.(safeName) = uicontrol(fig,'Style','popupmenu',...
            'String', options,...
            'Value',  valIdx,...
            'Position',[editX yPos editW 25],...
            'BackgroundColor','white',...
            'FontSize', 10);
    else
        handles.(safeName) = uicontrol(fig,'Style','edit',...
            'String', num2str(val),...
            'Position',[editX yPos editW 25],...
            'BackgroundColor','white',...
            'FontSize', 10);
    end

    % Store metadata for the confirm callback
    fieldMeta(i).fieldName  = fieldName;
    fieldMeta(i).safeName   = safeName;
    fieldMeta(i).pPath      = pPath;
    fieldMeta(i).isDropdown = isDropdown;
    fieldMeta(i).options    = options;
end

% -------- Buttons --------
btnY = 20;
uicontrol(fig,'Style','pushbutton',...
    'String','  Confirm','FontWeight','bold','FontSize',11,...
    'Position',[100 btnY 140 42],...
    'BackgroundColor',[0.4 0.75 0.4],'ForegroundColor','white',...
    'Callback',@confirmCallback);

uicontrol(fig,'Style','pushbutton',...
    'String','  Cancel','FontWeight','bold','FontSize',11,...
    'Position',[280 btnY 140 42],...
    'BackgroundColor',[0.8 0.35 0.35],'ForegroundColor','white',...
    'Callback',@cancelCallback);

% -------- Wait for user --------
confirmed = false;
uiwait(fig);

% =========================================================================
%  CALLBACKS
% =========================================================================

    function confirmCallback(~,~)
        for j = 1:n
            meta = fieldMeta(j);

            if meta.isDropdown
                idx = handles.(meta.safeName).Value;
                val = string(meta.options{idx});
            else
                txt = handles.(meta.safeName).String;
                val = try_num(txt);
            end

            P = set_nested(P, meta.pPath, val);
        end
        confirmed = true;
        uiresume(fig);
        delete(fig);
    end

    function cancelCallback(~,~)
        confirmed = false;
        uiresume(fig);
        delete(fig);
    end

end   % ---- main function -------------------------------------------------


% =========================================================================
%  HELPERS
% =========================================================================

function [pPath, labelStr] = field_to_ppath(fieldName)
% Map a UI field name to a cell-array path into P and a display label.
%
% Special cases:
%   'eyetracker_system'  →  {'eyetracker','system'}
%   'Text.taskCondition' →  {'Text','taskCondition'}
%   'subjectID'          →  {'subjectID'}
%
    switch fieldName
        case 'eyetracker_system'
            pPath    = {'eyetracker','system'};
            labelStr = 'eyetracker.system';
        otherwise
            parts    = strsplit(fieldName, '.');
            pPath    = parts;
            labelStr = fieldName;
    end
end


function val = get_nested(S, pathCell)
% Read a (possibly nested) field from struct S.
% pathCell = {'fieldA'} or {'fieldA','fieldB'}
    val = S;
    for k = 1:numel(pathCell)
        val = val.(pathCell{k});
    end
end


function S = set_nested(S, pathCell, val)
% Write val into a (possibly nested) field of struct S.
    switch numel(pathCell)
        case 1
            S.(pathCell{1}) = val;
        case 2
            S.(pathCell{1}).(pathCell{2}) = val;
        case 3
            S.(pathCell{1}).(pathCell{2}).(pathCell{3}) = val;
        otherwise
            error('set_nested: path depth > 3 not supported');
    end
end


function val = try_num(txt)
% Return a number if txt parses as one, otherwise return trimmed string.
    num = str2double(txt);
    if ~isnan(num)
        val = num;
    else
        val = strtrim(txt);
    end
end