﻿using System;
using ConfirmIt.PortalLib.BusinessObjects.RuleEnities.Rules.DetailsOfRules;
using ConfirmIt.PortalLib.BusinessObjects.Rules;
using Core.ORM.Attributes;

namespace ConfirmIt.PortalLib.BusinessObjects.RuleEnities.Rules
{
    [DBTable("Rules")]
    public class NotifyByTimeRule : Rule
    {
        public string Information { get; set; }
        public DateTime Time { get; set; }
        public DayOfWeek DayOfWeek { get; set; }

        public override RuleKind RuleType
        {
            get { return RuleKind.NotifyByTime; }
        }

        public NotifyByTimeRule(){}

        public NotifyByTimeRule(string information, DateTime time, DayOfWeek dayOfWeek)
        {
            Information = information;
            Time = time;
            DayOfWeek = dayOfWeek;
            RuleDetails = new NotifyByTimeRuleDetails(information, time, dayOfWeek);
        }

        public override void DeserializeInstance()
        {
            var ruleDetails = new SerializeHelper<NotifyByTimeRuleDetails>().GetInstance(XmlInformation);
            DayOfWeek = ruleDetails.DayOfWeek;
            Time = ruleDetails.Time;
            Information = ruleDetails.Information;
        }
    }
}