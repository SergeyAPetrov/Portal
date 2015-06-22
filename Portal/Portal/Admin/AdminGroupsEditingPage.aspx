﻿<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="AdminGroupsEditingPage.aspx.cs" Inherits="Portal.Admin.AdminGroupEditingPage"
    MasterPageFile="~/MasterPages/Main.master" %>

<%@ Register Src="~/Controls/GroupsControls/GroupCreatorControl.ascx" TagPrefix="uc" TagName="GroupCreatorControl" %>
<%@ Register Src="~/Controls/AdminGroupsEditingControl.ascx" TagPrefix="uc" TagName="GroupsEditingControl" %>
<%@ Register Src="~/Controls/GroupsControls/UserListInGroupControl.ascx" TagPrefix="uc" TagName="UserGroupsSelectionControl" %>

<asp:Content ID="ContentMain" ContentPlaceHolderID="MainContentPlaceHolder" runat="server">
    <uc:GroupCreatorControl ID="GroupCreator" runat="server" />
    <div style="display: inline-flex;">
       <div style="float: left; display: inline-flex;">
            <uc:GroupsEditingControl ID="ControlForEditingGroups" runat="server" />
       </div>
       <div style="float: left; display: inline-flex;">
            <uc:UserGroupsSelectionControl ID="UsersListForCurrentGroupControl" runat="server" />
       </div>
    </div>
</asp:Content>
