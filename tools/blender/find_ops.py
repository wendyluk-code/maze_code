import bpy
ops = [o.idname() for o in bpy.ops.vm.? if 'pmx' in o.idname().lower() or 'mmd' in o.idname().lower()]
