//
//  ViewController.m
//  练习测试
//
//  Created by wuliangzhi on 2020/5/17.
//  Copyright © 2020 wuliangzhi. All rights reserved.
//主题:断点续传
/*1.断点续传的工作机制:在HTTP请求头中,有一个Range的关键字,通过这个关键字可以告诉服务器返回那些数据给我,比如:
 bytes = 500-999 表示第500-第999字节
 bytes = 500- 表示第500字节往后的所有字节
 然后我们再根据服务器返回的数据,将得到的data数据拼接到文件后面,就可以实现断点续传了
 */
#import "ViewController.h"
#import <iconv.h>

#define _1M 1024*1024

@interface ViewController ()<NSURLSessionDownloadDelegate>

@property(nonatomic,strong)NSURLSession *backgroudSession; /** <session对象 */
@property(nonatomic,strong)NSFileManager *manager; /** <文件管理 */
@property(nonatomic,strong)NSString *docPath; /** <文件存放路径 */
@property(nonatomic,strong)NSURLSessionDownloadTask *task; /** <文件下载任务 */
@property(nonatomic,strong)NSData *fileData; /** <下载的文件路径 */
@property(nonatomic,strong)UILabel *lab; /** <文本显示 */
@property(nonatomic,assign)long long int byte; /** <<#注释#> */

@property (weak, nonatomic) IBOutlet UIProgressView *progressView;


@end

@implementation ViewController
{
    NSString *dataPath; //实时存储resumeData
    NSString *tmpPath;
    NSString *docFilePath;
    
    BOOL needPause;
}

#pragma mark- 懒加载
- (NSString *)docPath{
    if (!_docPath) {
        _docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    }
    return _docPath;
}

- (NSFileManager *)manager{
    if (!_manager) {
        _manager = [NSFileManager defaultManager];
    }
    return _manager;
}

- (NSURLSession *)backgroudSession{
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *identifier = @"background";
        NSURLSessionConfiguration *sessionCofig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        session = [NSURLSession sessionWithConfiguration:sessionCofig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    });
    return session;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    dataPath = [self.docPath stringByAppendingPathComponent:@"file.db"];
    NSLog(@"文件夹路径:%@",dataPath);
    
    _lab = [[UILabel alloc]initWithFrame:CGRectMake(40, 300, 200, 40)];
    _lab.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:_lab];
}

#pragma mark- NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    NSString *filePath = [self.docPath stringByAppendingPathComponent:@"file.mp4"];
    [self.manager moveItemAtURL:location toURL:[NSURL fileURLWithPath:filePath] error:nil];
    [self.manager removeItemAtPath:dataPath error:nil];
    [self.manager removeItemAtPath:docFilePath error:nil];
    _fileData = nil;
    NSLog(@"下载完成:%@",filePath);
    
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    _lab.text = [NSString stringWithFormat:@"下载中,进度为%.2f",totalBytesWritten *100.0/totalBytesExpectedToWrite];
    _byte += bytesWritten;
    //1k=1024字节,1M=1024k,这里设置每下载1M保存一次,大家可以自行设置
    if (_byte > _1M) {
        [self downloadPause];
        _byte -= _1M;
    }
    self.progressView.progress = (double)totalBytesWritten/totalBytesExpectedToWrite;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes{
    NSLog(@"%s",__func__);
}


#pragma mark- Action
//开始下载
- (IBAction)startDownLoad {
    
    //1.创建下载任务
    NSString *downLoadURLString = @"http://vfx.mtime.cn/Video/2019/03/19/mp4/190319212559089721.mp4";
    NSURL *downloadURL = [NSURL URLWithString:downLoadURLString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadURL];
    
    _fileData = [NSData dataWithContentsOfFile:dataPath];
    if (_fileData) {
        NSString *Caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        [self.manager removeItemAtPath:Caches error:nil];
        [self MoveDownloadFile];
        _task = [self.backgroudSession downloadTaskWithResumeData:_fileData];
    }
    else
    {
        _task = [self.backgroudSession downloadTaskWithRequest:request];
    }
    
    _task.taskDescription = [NSString stringWithFormat:@"后台下载"];
    //开始任务
    [_task resume];
    
}

//暂停下载
- (IBAction)pauseDownLoad {
    needPause = YES;
    
    [_task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        //        [resumeData writeToFile:@"/Users/wuliangzhi/Desktop/file.plist" atomically:YES];
        //1.保存resumeData
        _fileData = resumeData;
        [resumeData writeToFile:dataPath atomically:YES];
        _task = nil;
        [self getDownloadFile];
    }];
}

//继续下载
- (IBAction)resumeDownLoad {
    if (_fileData) {
        _task = [self.backgroudSession downloadTaskWithResumeData:_fileData];
        [_task resume];
        _fileData = nil;
    }else{
        [self startDownLoad];
    }
}

#pragma mark- private method
//暂停下载,获取文件指针和缓存文件

- (void)downloadPause
{
    [_task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        _fileData = resumeData;
        _task = nil;
        [resumeData writeToFile:dataPath atomically:YES];
        [self getDownloadFile];
        
        needPause = NO;
    }];
    
}


//获取系统生成的文件
- (void)getDownloadFile{
    
    //调用暂停方法之后,下载的文件会从下载文件夹移动到tmp文件夹
    NSArray *paths = [self.manager subpathsAtPath:NSTemporaryDirectory()];
    //    NSLog(@"临时文件夹路径:%@",paths);
    for (NSString *filePath in paths) {
        if ([filePath rangeOfString:@"CFNeworkDownload"].length>0) {
            tmpPath = [self.docPath stringByAppendingPathComponent:filePath];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filePath];
            //tmp文件夹中的文件随时有可能被删除,所以要移动到安全目录下
            [self.manager copyItemAtPath:path toPath:tmpPath error:nil];
            
            //建议创建一个plist表来管理,可以通过task的response的***name获取到文件名称,kvc存储或者直接建立数据库来进行文件管理,不然文件多了可能会混乱...
        }
    }
}

//将存储的tmp文件移动到tmp路径下,
- (void)MoveDownloadFile{
    NSArray *paths = [self.manager subpathsAtPath:_docPath];
    for (NSString *filePath in paths) {
        if ([filePath rangeOfString:@"CFNetworkDownload"].length > 0) {
            docFilePath = [_docPath stringByAppendingPathComponent:filePath];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filePath];
            //反向移动
            [self.manager copyItemAtPath:docFilePath toPath:path error:nil];
            
            //建议创建一个plist表来管理,可以通过task的response的***name获取到文件名称,kvc存储或者直接建立数据库来进行文件管理,不然文件多了可能会管理混乱;
        }
    }
    
    NSLog(@"%@,%@",paths,[self.manager subpathsAtPath:NSTemporaryDirectory()]);
    
}

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



@end
