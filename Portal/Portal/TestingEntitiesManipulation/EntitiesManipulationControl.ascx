﻿<%@ Control Language="C#" AutoEventWireup="true" CodeBehind="EntitiesManipulationControl.ascx.cs" Inherits="Portal.TestingEntitiesManipulation.EntitiesManipulationControl" %>

<%@ Register Src="~/TestingEntitiesManipulation/EntitiesListControl.ascx" TagPrefix="uc" TagName="EntitiesListControl" %>

<table>
    <tr>
        <td style="vertical-align: auto;">
            <div id="EntitiesListIncluded">
                <uc:EntitiesListControl ID="EntitiesListIncludedControl" runat="server" />
            </div>
        </td>
        <td>
            <div style="height: 200px;">
                <div style="margin-top: 40px; margin-bottom: 15px;">
                    <asp:Button ID="RemoveEntitiesButton" runat="server" Text=" >> " />
                </div>
                <div style="height: 100px;">
                    <asp:Button ID="AddEntitiesButton" runat="server" Text=" << " />
                </div>
            </div>
        </td>
        <td style="vertical-align: auto;">
            <div id="EntitiesListNotIncluded">
                <uc:EntitiesListControl ID="EntitiesListNotIncludedControl" runat="server" />
            </div>
        </td>
    </tr>
</table>