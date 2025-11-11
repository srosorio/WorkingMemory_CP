function [ch, label] = tf_label(flag)
% -------------------------------------------------------------------------
% tf_label  |  Alavie - Sternberg WM Task Helper
%
% Converts a logical flag into corresponding True/False labels.
%
% USAGE
%   [ch, label] = tf_label(flag)
%
% INPUT
%   flag : logical scalar (true/false)
%
% OUTPUTS
%   ch    : character 'T' or 'F'
%   label : character array 'True' or 'False' (char, not string)
%
% EXAMPLE
%   [ch, label] = tf_label(true)
%       -> ch = 'T', label = 'True'
%
%   [ch, label] = tf_label(false)
%       -> ch = 'F', label = 'False'
%
% NOTES
%   - Ensures input is a single logical value.
%   - Useful for concise labeling in event logs or behavioral data.
% -------------------------------------------------------------------------

if nargin == 0 || ~islogical(flag) || numel(flag) ~= 1
    error('tf_label: flag must be a 1x1 logical value.');
end

if flag
    ch    = 'T';
    label = 'True';
else
    ch    = 'F';
    label = 'False';
end
end
