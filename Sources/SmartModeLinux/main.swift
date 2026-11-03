import CGtk

gtk_init(nil, nil)
let model = AppModel()
let tray = Tray(model: model)
model.start()
gtk_main()
_ = tray
