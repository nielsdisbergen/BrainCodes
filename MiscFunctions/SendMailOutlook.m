function SendMailOutlook(recip, subj, txtBod, varargin)
% @Niels R. Disbergen - 17 Jun 2015
%
% This function sends an email from outlook through actxserver. Personal use
% mostly to send message when analysis have been completed or errors generated.
% Barebone implementation, tested on Windows 7 SP1 with Outlook 2010
%
% Syntax:
%   - SendMailOutlook(recip, subj, txtBod)
%   - SendMailOutlook(recip, subj, txtBod, attToMail)
%
% Input:
%   recip = email address (str)
%   subj = email subject (str)
%   txtBod = message body (str)
%   attToMail = attachments, full paths (cell)
%

    narginchk(3,4)

    % access outlook through actx
    outLook = actxserver('outlook.Application');

    % create new message and add content
    message = outLook.CreateItem('olMail');
    message.Subject = subj;
    message.To = recip;
    message.HTMLBody = txtBod;
    message.BodyFormat = 'olFormatHTML';

    if nargin == 4
        attToMail = varargin{1};
        if iscell(attToMail)
            for cntAttch = 1:length(attToMail)
                message.attachments.Add(attToMail{cntAttch});
            end
        else
            error('Attachment(s) not in cell format')
        end
    end

    % send message and release outlook
    message.Send;
    outLook.release;
    clear message outLook

end
