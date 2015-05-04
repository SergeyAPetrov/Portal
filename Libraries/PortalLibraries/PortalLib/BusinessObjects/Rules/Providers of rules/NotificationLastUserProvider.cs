﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using ConfirmIt.PortalLib.BusinessObjects.Rules.RealizationViaOneTable;

namespace ConfirmIt.PortalLib.BusinessObjects.Rules.Providers_of_rules
{
    public class NotificationLastUserProvider : RuleProvider
    {
        private List<NotificationRuleLastUser> _rules; 
        public override RuleKind TypeOfRule
        {
            get { return RuleKind.NotificationLastUser; }
        }

        public NotificationLastUserProvider()
        {
            _rules = new List<NotificationRuleLastUser>();
            FillRulesId();
        }

        public List<NotificationRuleLastUser> GetRules()
        {
            if (_rules.Count != 0) return _rules;

            foreach (var id in RulesId)
            {
                var rule = new NotificationRuleLastUser();
                if (rule.Load(id))
                {
                    _rules.Add(rule);
                }
            }
            return _rules;
        }
    }
}