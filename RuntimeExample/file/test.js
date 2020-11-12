// 定义使用到的类
require("UIButton, UIColor","UIViewController","UITableView","UITableViewCell","TestViewController");
defineClass("ViewController", {
  viewDidLoad: function() {
    self.super().viewDidLoad();
    var textBtn = UIButton.alloc().initWithFrame({x:30, y:140, width:100, height:100});
    self.view().addSubview(textBtn);
    textBtn.setBackgroundColor(UIColor.blueColor());
    textBtn.addTarget_action_forControlEvents(self, "handleBtn", 1);
    self.view().setBackgroundColor(UIColor.yellowColor());
    // 设置属性
    self.setShowText("显示文字33333");
  }
}, {});
