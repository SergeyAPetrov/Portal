﻿using System;
using ConfirmIt.PortalLib.BusinessObjects.RuleEnities.Rules.DetailsOfRules;
using ConfirmIt.PortalLib.BusinessObjects.Rules;
using Core.ORM.Attributes;

namespace ConfirmIt.PortalLib.BusinessObjects.RuleEnities.Rules
{
    [DBTable("Rules")]
    public class AddWorkTimeRule : Rule
    {
        public DayOfWeek DayOfWeek { get; set; }
        public TimeSpan Interval { get; set; }
        
        public override RuleKind RuleType
        {
            get { return RuleKind.AddWorkTime; }
        }
        
        public AddWorkTimeRule() { }

        public AddWorkTimeRule(TimeSpan interval, DayOfWeek dayOfWeek)
        {
            Interval = interval;
            DayOfWeek = dayOfWeek;
            RuleDetails = new AddWorkTimeRuleDetails(interval, dayOfWeek);
        }

        public override void DeserializeInstance()
        {
            var ruleDetails = new SerializeHelper<AddWorkTimeRuleDetails>().GetInstance(XmlInformation);
            DayOfWeek = ruleDetails.DayOfWeek;
            Interval = ruleDetails.Interval;
        }
    }
}