function OutlookCalendarEntry(subjEvent, textBody, dateEvent, timeFrame)
%
% @Niels R. Disbergen - 17 Jun 2015
%
% This function creates a calendar entry in Outlook through actxserver with a
% title and an optional descriptive text. A reminder is set automatically
% five minutes before the scheduled even start time. This is a barebone
% implementation, tested on Windows 7 SP1 with Outlook 2010
%
% Syntax:
%   - OutlookCalendarEntry(subject, textBody, date, timeFrame)
%
% Input:
%   subject = title of event (str)
%   textBody = descriptive text for event, can be empty (str)
%   dateEvent = date as integers [DD MM YYYY]
%   timeFrame = start and end time as strings ['HH:MM'; 'HH:MM']
%

%% check vars

    % error if subjEvent not character array
    if ~ischar(subjEvent)
        throw(MException('OutlookWindowsCalendarEntry:EventNameNotChar', 'Error: variable subjEvent is not a character array'))
    end

    % if empty date or size issue, set to today
    if isempty(dateEvent) || size(dateEvent, 2) ~= 3
        dateEvent = clock;
        dateEvent = dateEvent([3 2 1]);
    end

    % if empty time or size issue, set to 18:00 - 18:05
    if isempty(timeFrame) || size(timeFrame, 1) ~= 2 || size(timeFrame, 2) ~= 5
        timeFrame = ['18:00'; '18:05'];
    end


%% create calendar entry

    outlook = actxserver('outlook.Application');
    reminder = outlook.CreateItem('olAppointmentItem');

    reminder.Subject = subjEvent;
    reminder.Body = textBody;

    reminder.Start = sprintf('%i/%i/%i %s:00', dateEvent, timeFrame(1,:));
    reminder.End =  sprintf('%i/%i/%i %s:00', dateEvent, timeFrame(2,:));

    reminder.ReminderSet = 1;
    reminder.ReminderMinutesBeforeStart = 5;

    reminder.Save();

    clear reminder outlook

    fprintf('Reminder set for "%s"\n', subject)


end
