#include <iostream>

#ifndef TEMPLATE_H
#define TEMPLATE_H

const std::string jsonString = R"(
    {
        "CaptureVisionTemplates": [
            {
                "Name": "DetectAndNormalizeDocument_Default",
                "ImageROIProcessingNameArray": [
                    "roi-detect-and-normalize-document"
                ]
            },
            {
                "Name": "DetectDocumentBoundaries_Default",
                "ImageROIProcessingNameArray": [
                    "roi-detect-document-boundaries"
                ]
            },
            {
                "Name": "NormalizeDocument_Default",
                "ImageROIProcessingNameArray": [
                    "roi-normalize-document"
                ]
            }
        ],
        "TargetROIDefOptions": [
            {
                "Name": "roi-detect-and-normalize-document",
                "TaskSettingNameArray": [
                    "task-detect-and-normalize-document"
                ]
            },
            {
                "Name": "roi-detect-document-boundaries",
                "TaskSettingNameArray": [
                    "task-detect-document-boundaries"
                ]
            },
            {
                "Name": "roi-normalize-document",
                "TaskSettingNameArray": [
                    "task-normalize-document"
                ]
            }
        ],
        "DocumentNormalizerTaskSettingOptions": [
            {
                "Name": "task-detect-and-normalize-document",
                "SectionImageParameterArray": [
                    {
                        "Section": "ST_REGION_PREDETECTION",
                        "ImageParameterName": "ip-detect-and-normalize"
                    },
                    {
                        "Section": "ST_DOCUMENT_DETECTION",
                        "ImageParameterName": "ip-detect-and-normalize"
                    },
                    {
                        "Section": "ST_DOCUMENT_NORMALIZATION",
                        "ImageParameterName": "ip-detect-and-normalize"
                    }
                ]
            },
            {
                "Name": "task-detect-document-boundaries",
                "TerminateSetting": {
                    "Section": "ST_DOCUMENT_DETECTION"
                },
                "SectionImageParameterArray": [
                    {
                        "Section": "ST_REGION_PREDETECTION",
                        "ImageParameterName": "ip-detect"
                    },
                    {
                        "Section": "ST_DOCUMENT_DETECTION",
                        "ImageParameterName": "ip-detect"
                    },
                    {
                        "Section": "ST_DOCUMENT_NORMALIZATION",
                        "ImageParameterName": "ip-detect"
                    }
                ]
            },
            {
                "Name": "task-normalize-document",
                "StartSection": "ST_DOCUMENT_NORMALIZATION",
                "SectionImageParameterArray": [
                    {
                        "Section": "ST_REGION_PREDETECTION",
                        "ImageParameterName": "ip-normalize"
                    },
                    {
                        "Section": "ST_DOCUMENT_DETECTION",
                        "ImageParameterName": "ip-normalize"
                    },
                    {
                        "Section": "ST_DOCUMENT_NORMALIZATION",
                        "ImageParameterName": "ip-normalize"
                    }
                ]
            }
        ],
        "ImageParameterOptions": [
            {
                "Name": "ip-detect-and-normalize",
                "BinarizationModes": [
                    {
                        "Mode": "BM_LOCAL_BLOCK",
                        "BlockSizeX": 0,
                        "BlockSizeY": 0,
                        "EnableFillBinaryVacancy": 0
                    }
                ],
                "TextDetectionMode": {
                    "Mode": "TTDM_WORD",
                    "Direction": "HORIZONTAL",
                    "Sensitivity": 7
                }
            },
            {
                "Name": "ip-detect",
                "BinarizationModes": [
                    {
                        "Mode": "BM_LOCAL_BLOCK",
                        "BlockSizeX": 0,
                        "BlockSizeY": 0,
                        "EnableFillBinaryVacancy": 0
                    }
                ],
                "TextDetectionMode": {
                    "Mode": "TTDM_WORD",
                    "Direction": "HORIZONTAL",
                    "Sensitivity": 7
                }
            },
            {
                "Name": "ip-normalize",
                "BinarizationModes": [
                    {
                        "Mode": "BM_LOCAL_BLOCK",
                        "BlockSizeX": 0,
                        "BlockSizeY": 0,
                        "EnableFillBinaryVacancy": 0
                    }
                ],
                "TextDetectionMode": {
                    "Mode": "TTDM_WORD",
                    "Direction": "HORIZONTAL",
                    "Sensitivity": 7
                }
            }
        ]
    })";

#endif
