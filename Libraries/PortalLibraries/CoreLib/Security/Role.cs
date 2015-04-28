namespace Core.Security
{
	/// <summary>
	/// Роли пользователей системы
	/// </summary>
	public enum Role
	{
		Anonymous = 0,
		/// <summary>
		/// Администратор. 
		/// Сотрудник, имеющий возможность изменения всех объектов системы, 
		/// заведения новых объектов и удаления старых. 
		/// Роль доступна только для авторизованных пользователей имеющих соответствующие права в системе.
		/// </summary>
		Admin = 1,
		/// <summary>
		/// Редактор лицензионного проекта. 
		/// Сотрудник, имеющий полные права на определенный лицензионный проект, 
		/// а также имеющий возможность назначать права изменения конкретного этапа 
		/// лицензионного проекта редактору этапа. 
		/// Роль доступна только для авторизованных пользователей имеющих соответствующие права в системе.
		/// </summary>
		ProjectEditor = 2,
		/// <summary>
		/// Редактор стадии проекта. 
		/// Сотрудник, имеющий права на любые действия с назначенным ему 
		/// Редактором лицензионного проекта этапом данного проекта. 
		/// Роль доступна только для авторизованных пользователей имеющих соответствующие права в системе.
		/// </summary>
		StageEditor = 3,
		/// <summary>
		/// Pедактор оценки корпоративного центра.
		/// Сотрудник, имеющий право оценивать параметр "Контроль" проектов и стадий.
		/// </summary>
		ValuationEditor = 4,
		/// <summary>
		/// Доступ только на чтение. 
		/// Сотрудник, не имеющий прав изменения объектов системы, 
		/// имеющий доступ только для просмотра всей информации. 
		/// Роль доступна только для авторизованных пользователей 
		/// имеющих соответствующие права в системе. 
		/// Роль предназначена для высшего руководства компании, 
		/// в рамках должностных обязанностей имеющих отношение к лицензионным участкам.
		/// </summary>
		User = 5
	}
}