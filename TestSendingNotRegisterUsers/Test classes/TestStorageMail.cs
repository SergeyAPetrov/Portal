﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using ConfirmIt.PortalLib.Notification;

namespace TestSendingNotRegisterUsers
{
    class TestStorageMail : IStorageMail
    {
        public int countSavingLetters;
        public bool IsSave;
        public IList<MailItem> GetLetters(bool isSend)
        {
            return new List<MailItem> {new MailItem(), new MailItem(), new MailItem()};
        }

        public void SaveMail(MailItem letter)
        {
            IsSave = true;
            countSavingLetters++;
        }
    }
}