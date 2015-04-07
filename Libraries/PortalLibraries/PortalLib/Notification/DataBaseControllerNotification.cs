﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using ConfirmIt.PortalLib.BAL;
using UlterSystems.PortalLib.BusinessObjects;

namespace ConfirmIt.PortalLib.Notification
{
    public class DataBaseControllerNotification : IControllerNotification
    {
        public bool IsNotify(Person user)
        {
            // Не оповещать не слущажих.
            // Не оповещать служащих, не имеющих адреса электронной почты.
            // Не оповещать московских служащих.
            if (!user.IsInRole("Employee")
                || string.IsNullOrEmpty(user.PrimaryEMail)
                || user.EmployeesUlterSYSMoscow) return false;

            return true;
        }

        public bool IsNotify(DateTime date)
        {
            if (CalendarItem.GetHoliday(DateTime.Now)) 
                return false;

            return true;
        }
    }
}