object repwebmod: Trepwebmod
  OldCreateOrder = False
  OnCreate = WebModuleCreate
  OnDestroy = WebModuleDestroy
  Actions = <
    item
      Name = 'aroot'
      PathInfo = '/'
      OnAction = repwebmodarootAction
    end
    item
      Name = 'aversion'
      PathInfo = '/version'
      OnAction = repwebmodaversionAction
    end
    item
      Name = 'aindex'
      PathInfo = '/index'
      OnAction = repwebmodaindexAction
    end
    item
      Name = 'alogin'
      PathInfo = '/login'
      OnAction = repwebmodaloginAction
    end
    item
      Name = 'ashowalias'
      PathInfo = '/showalias'
      OnAction = repwebmodashowaliasAction
    end
    item
      Name = 'ashowparams'
      PathInfo = '/showparams'
      OnAction = repwebmodashowparamsAction
    end
    item
      Name = 'aexecute'
      PathInfo = '/execute.pdf'
      OnAction = repwebmodaexecuteAction
    end
    item
      Name = 'aexecute2'
      PathInfo = '/execute'
      OnAction = repwebmodaexecute2Action
    end
    item
      Name = 'aadmin'
      PathInfo = '/admin'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminbootstrap'
      PathInfo = '/admin/bootstrap'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminlogin'
      PathInfo = '/admin/login'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminserverconfig'
      PathInfo = '/admin/server-config'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminconnections'
      PathInfo = '/admin/connections'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminconnectionsnew'
      PathInfo = '/admin/connections/new'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminconnectionsedit'
      PathInfo = '/admin/connections/edit'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminconnectionsdelete'
      PathInfo = '/admin/connections/delete'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminconnectionsraw'
      PathInfo = '/admin/connections/raw'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminconnectionstest'
      PathInfo = '/admin/connections/test'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminusers'
      PathInfo = '/admin/users'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminusersnew'
      PathInfo = '/admin/users/new'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminusersedit'
      PathInfo = '/admin/users/edit'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminusersdelete'
      PathInfo = '/admin/users/delete'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadmingroups'
      PathInfo = '/admin/groups'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadmingroupsnew'
      PathInfo = '/admin/groups/new'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadmingroupsedit'
      PathInfo = '/admin/groups/edit'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadmingroupsdelete'
      PathInfo = '/admin/groups/delete'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminaliases'
      PathInfo = '/admin/aliases'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminaliasesnew'
      PathInfo = '/admin/aliases/new'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminaliasesedit'
      PathInfo = '/admin/aliases/edit'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminaliasesdelete'
      PathInfo = '/admin/aliases/delete'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminapikeys'
      PathInfo = '/admin/apikeys'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminapikeysnew'
      PathInfo = '/admin/apikeys/new'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadminapikeysdelete'
      PathInfo = '/admin/apikeys/delete'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'aadmindiagnostics'
      PathInfo = '/admin/diagnostics'
      OnAction = repwebmodaadminAction
    end
    item
      Name = 'admintesting'
      PathInfo = '/admin/testing'
      OnAction = repwebmodaadminAction
    end>
  Left = 200
  Top = 154
  Height = 150
  Width = 215
end
