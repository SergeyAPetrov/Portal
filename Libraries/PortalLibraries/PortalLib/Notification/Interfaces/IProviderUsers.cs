﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using UlterSystems.PortalLib.BusinessObjects;

namespace ConfirmIt.PortalLib.Notification
{
    public interface IProviderUsers
    {
        IList<Person> GetAllEmployees();
    }
}