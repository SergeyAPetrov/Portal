﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using ConfirmIt.PortalLib.BusinessObjects.Rules.RealizationViaOneTable;

namespace ConfirmIt.PortalLib.BusinessObjects.Rules.Providers_of_rules
{
    public class NotificationByTimeProvider : RuleProvider
    {
        private List<NotificationRuleByTime> _rules; 
        public override RuleKind TypeOfRule
        {
            get { return RuleKind.NotificatationByTime; }
        }

        public NotificationByTimeProvider()
        {
            _rules = new List<NotificationRuleByTime>();
            FillRulesId();
        }

        public List<NotificationRuleByTime> GetRules()
        {
            if (_rules.Count != 0) return _rules;

            foreach (var id in RulesId)
            {
                var rule = new NotificationRuleByTime();
                if (rule.Load(id))
                {
                    _rules.Add(rule);
                }
            }
            return _rules;
        }
    }
}