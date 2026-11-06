import sys
from ultralytics import YOLO
m=YOLO('base_train6.pt')
m.train(data='../ds/data.yaml',epochs=int(sys.argv[1]),imgsz=640,batch=32,device='mps',workers=4,
        mosaic=0.2,scale=0.25,translate=0.05,fliplr=0.5,flipud=0.0,degrees=0.0,patience=20,
        optimizer='SGD',lr0=0.001,lrf=0.1,momentum=0.9,warmup_epochs=0.3,warmup_bias_lr=0.0,project='/private/tmp/claude-501/-Users-thierry-Developer-ChessLab/2360b861-4f51-4ec0-b762-974d3fa95194/scratchpad/runs',name='ft3',exist_ok=True,plots=False,val=False,save_period=1)
