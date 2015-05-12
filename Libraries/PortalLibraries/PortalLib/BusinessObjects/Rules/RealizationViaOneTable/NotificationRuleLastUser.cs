﻿using System.Collections.Generic;
using Core.ORM.Attributes;

namespace ConfirmIt.PortalLib.BusinessObjects.Rules.RealizationViaOneTable
{
    [DBTable("Rules")]
    public class NotificationRuleLastUser : Rule
    {
        public string Subject { get; set; }

        protected override string GetXmlRepresentation()
        {
            var helper = new SerializeHelper<NotificationRuleLastUser>();
            return helper.GetXml(this);
        }

        protected override void LoadFromXlm()
        {
            var helper = new SerializeHelper<NotificationRuleLastUser>();
            BuildThisInstance(helper.GetInstance(XmlInformation));
        }

        public override RuleKind GetRuleType()
        {
            return RuleKind.NotificationLastUser;
        }

        private void BuildThisInstance(NotificationRuleLastUser instance)
        {
            this.Subject = instance.Subject;
            this.ID = instance.ID;
        }

        public NotificationRuleLastUser()
        {
            GroupIdentifiers = new List<int>();
        }

        public NotificationRuleLastUser(string subject)
        {
            Subject = subject;
            GroupIdentifiers = new List<int>();
            ResolveConnection();
        }

        public NotificationRuleLastUser(string subject, List<int> groupsId)
            : this(subject)
        {
            GroupIdentifiers = new List<int>(groupsId);
        }
    }
}
