function update_vocal_responses(participant_id, runProfile, condition)
%UPDATE_VOCAL_RESPONSES Update task CSV with vocal responses from Whisper
%
% This function reads the original CSV exported from the task and the JSON
% containing transcribed vocal responses, then updates the CSV with the
% actual responses (digits recalled and distractor responses).
%
% Example usage:
%   update_vocal_responses()

%% --------------------------
% --- User settings ---
%% --------------------------
mainDir = 'C:\Users\saosorio\Projects\WorkingMemory_CP\SternbergTask-PSB\output';

% CSV exported from task
csv_path = fullfile(mainDir, runProfile, participant_id, condition, ...
    sprintf('%s_%s__*_Same Order_%s_events.csv', ...
    participant_id,condition,runProfile));
csv_struct = dir(csv_path);

% ---- SAFETY CHECKS ----
assert(~isempty(csv_struct), ...
    'No CSV file found matching pattern:\n%s', csv_path);

assert(numel(csv_struct) == 1, ...
    'Expected exactly 1 CSV file, found %d:\n%s', ...
    numel(csv_struct), strjoin({csv_struct.name}, '\n'));

csv_file = fullfile(csv_struct.folder,csv_struct.name);

% JSON with transcribed vocal responses
json_file = fullfile(mainDir, runProfile, participant_id, condition, 'AudioFiles', 'transcriptions_clean.json');

% Output CSV
output_csv = replace(csv_file, '.csv', '_updated.csv');

%% --------------------------
% --- Load CSV table ---
%% --------------------------
opts = detectImportOptions(csv_file,'Delimiter',',');
opts = setvartype(opts,'char');  % Read all as char to safely handle JSON
T = readtable(csv_file, opts);

%% --------------------------
% --- Load JSON transcriptions ---
%% --------------------------
fid = fopen(json_file,'r');
if fid == -1
    error('Cannot open JSON file: %s', json_file);
end
raw = fread(fid, inf);
str = char(raw');
fclose(fid);
data_json = jsondecode(str);

%% --------------------------
% --- Update reading digit ---
%% --------------------------
for i = 1:height(T)
    row = T(i,:);
    if strcmp(row.phase, 'reading') && contains(row.event_name, 'PROBE_COUNT_OK')
        % Extract slot number from event_name (e.g., PROBE_DIGIT_OK_1 -> 1)
        tokens = regexp(row.event_name, 'PROBE_COUNT_OK_(\d+)', 'tokens');
        if ~isempty(tokens)
            slot_num = str2double(tokens{1}{1});
            % Construct the audio filename for this slot
            % For probe digits
            audio_file = sprintf('%s_Block%02d_Trial%02d_Digit%02d.wav', ...
                row.subject{1}, str2double(row.block{1}), ...
                str2double(row.trial{1}), slot_num);

            audio_field = strrep(audio_file, '.', '_'); % match JSON field

            if isfield(data_json, audio_field)
                entered = data_json.(audio_field);

                % Update entered_value column (replace NaN)
                T.entered_value{i} = num2str(entered);

                % Update JSON field in table
                row_json = jsondecode(T.json{i});
                row_json.entered = entered;
                T.json{i} = jsonencode(row_json);

                % add correct or incorrect
                isCorrect = strcmp(T.value_shown{i-1}, T.entered_value{i});
                T.correct{i} = num2str(isCorrect);
            end
        end
    end
end


%% --------------------------
% --- Update probe digit recall ---
%% --------------------------
for i = 1:height(T)
    row = T(i,:);
    if strcmp(row.phase, 'probe') && contains(row.event_name, 'PROBE_DIGIT_OK')
        % Extract slot number from event_name (e.g., PROBE_DIGIT_OK_1 -> 1)
        tokens = regexp(row.event_name, 'PROBE_DIGIT_OK_(\d+)', 'tokens');
        if ~isempty(tokens)
            slot_num = str2double(tokens{1}{1});
            % Construct the audio filename for this slot
            % For probe digits
            audio_file = sprintf('%s_Block%02d_Trial%02d_Digit%02d.wav', ...
                row.subject{1}, str2double(row.block{1}), ...
                str2double(row.trial{1}), slot_num);

            audio_field = strrep(audio_file, '.', '_'); % match JSON field

            if isfield(data_json, audio_field)
                entered = data_json.(audio_field);

                % Update entered_value column (replace NaN)
                T.entered_value{i} = num2str(entered);

                % Update JSON field in table
                row_json = jsondecode(T.json{i});
                row_json.entered = entered;
                T.json{i} = jsonencode(row_json);

                % add correct or incorrect
                isCorrect = strcmp(T.value_shown{i-(26+slot_num)},T.entered_value{i});
                T.correct{i} = num2str(isCorrect);
            end
        end
    end
end


%% --------------------------
% --- Update distractor responses ---
%% --------------------------
for i = 1:height(T)
    row = T(i,:);
    if strcmp(row.phase,'distractor') && strcmp(row.event_name,'DISTRACTOR_ANS')
        % Construct corresponding audio filename
        % For distractor
        audio_file = sprintf('%s_Block%02d_Trial%02d_TrueFalse.wav', ...
            row.subject{1}, str2double(row.block{1}), ...
            str2double(row.trial{1}));

        if isfield(data_json, audio_file)
            entered = data_json.(audio_file);

            % Update entered_value column
            T.entered_value{i} = entered;

            % Update JSON field and recompute correctness
            row_json = jsondecode(T.json{i});
            row_json.entered = entered;
            if isfield(row_json,'truth')
                row_json.correct = (entered == row_json.truth);
            end
            T.json{i} = jsonencode(row_json);
        end
    end
end

%% --------------------------
% --- Save updated CSV ---
%% --------------------------
writetable(T, output_csv, 'Delimiter', ',', 'QuoteStrings', true);

fprintf('✅ Updated CSV saved to: %s\n', output_csv);
end
