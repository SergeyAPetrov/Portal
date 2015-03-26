﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace ConfirmIt.PortalLib.Notification
{
    public interface IStorageMail
    {
        IList<MailItem> GetMails(bool isSend);
        void SaveMail(MailItem mail);
    }
}
