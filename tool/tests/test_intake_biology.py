import hashlib
import json
import struct
import unittest
from tool.resource_intake.biology import inspect_vector_bundle
from tool.resource_intake.common import IntakeError


def bundle():
    files = {'content.jsonl': b'{"chunk_id":"test-only"}\n',
             'vector_map.jsonl': b'{"row_index":0,"chunk_id":"test-only"}\n',
             'vectors.f32le': struct.pack('<ff', 1, 0)}
    config = dict(dimensions=2, row_count=1, index_kind='EXACT_FLAT_RAW_VECTORS_NO_SEPARATE_INDEX_FILE',
                  dtype='float32', endianness='little', layout='row_major',
                  model_sha256='a'*64)
    for file, key in [('content.jsonl','content_sha256'), ('vector_map.jsonl','vector_map_sha256'), ('vectors.f32le','vector_file_sha256')]:
        config[key]=hashlib.sha256(files[file]).hexdigest()
    files['index_config.json'] = json.dumps(config).encode()
    files['embedding_config.json'] = json.dumps(dict(dimensions=2, model_sha256='a'*64)).encode()
    return files


class BiologyTest(unittest.TestCase):
    def test_valid_vector_binding(self):
        self.assertEqual(inspect_vector_bundle(bundle(), 'a'*64)['rows'], 1)

    def test_changed_bytes_or_wrong_embedding(self):
        for key in ['content.jsonl','vector_map.jsonl','vectors.f32le']:
            files=bundle(); files[key]+=b'!'
            with self.subTest(key=key), self.assertRaises(IntakeError): inspect_vector_bundle(files,'a'*64)
        with self.assertRaises(IntakeError): inspect_vector_bundle(bundle(),'b'*64)

    def test_nonfinite_and_zero_vectors(self):
        for a,b in [(float('nan'),1),(float('inf'),0),(0,0)]:
            files=bundle(); files['vectors.f32le']=struct.pack('<ff',a,b)
            config=json.loads(files['index_config.json']); config['vector_file_sha256']=hashlib.sha256(files['vectors.f32le']).hexdigest()
            files['index_config.json']=json.dumps(config).encode()
            with self.subTest(a=a), self.assertRaises(IntakeError): inspect_vector_bundle(files,'a'*64)

    def test_map_order_and_size(self):
        for key,value in [('row_index',1),('chunk_id','different')]:
            files=bundle(); row=json.loads(files['vector_map.jsonl']); row[key]=value
            files['vector_map.jsonl']=json.dumps(row).encode()+b'\n'
            config=json.loads(files['index_config.json']); config['vector_map_sha256']=hashlib.sha256(files['vector_map.jsonl']).hexdigest()
            files['index_config.json']=json.dumps(config).encode()
            with self.subTest(key=key), self.assertRaises(IntakeError): inspect_vector_bundle(files,'a'*64)

    def test_invalid_dimensions(self):
        for dimension in [True,0,3]:
            files=bundle(); config=json.loads(files['index_config.json']); config['dimensions']=dimension
            files['index_config.json']=json.dumps(config).encode()
            with self.subTest(dimension=dimension), self.assertRaises(IntakeError): inspect_vector_bundle(files,'a'*64)
