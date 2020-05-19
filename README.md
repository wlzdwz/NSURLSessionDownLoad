# NSURLSessionDownLoad
基于NSURLSession的断点续存
实现的思路参考链接:http://www.cocoachina.com/articles/16053
关于ResumeData:https://www.jianshu.com/p/da565e14ef88
自己做的补充和更改:
按照参考思路的实现,是在暂停过程中加了延迟之后再恢复下载,代码实现:
//暂停下载,获取文件指针和缓存文件
- (void)downloadPause
{
    
    NSLog(@"%s",__func__);
    [_task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        _fileData = resumeData;
        _task = nil;
        [resumeData writeToFile:dataPath atomically:YES];
        [self getDownloadFile];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //做完保存操作之后让他继续下载
            if (_fileData)
            {
                _task = [self.backgroundURLSession downloadTaskWithResumeData:_fileData];
                [_task resume];
            }
        });
    }];
}

这样在进度条的走动过程中会明显的感觉到下载停顿,但是若不加延迟再resume,程序有时候会莫名暂停下载.但是我发现,一旦调用了cancelByProducingResumeData:方法,在该block内容执行完毕之后会调用方法
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
我们可以在这个方法里面恢复下载:
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (error) {
        if (!needPause) {
            NSLog(@"下载失败:%@",error);
            _fileData = error.userInfo[NSURLSessionDownloadTaskResumeData];
            [_fileData writeToFile:dataPath atomically:YES];
            //        [self resumeDownLoad];
            _task = [self.backgroudSession downloadTaskWithResumeData:_fileData];
            [_task resume];
        }
    }
    
    NSLog(@"%s",__func__);
}



