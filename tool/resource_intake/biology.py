"""Static pilot evidence only; no retrieval, science policy or activation."""
import hashlib
import math
import struct
from .common import IntakeError, strict_json


def inspect_vector_bundle(files, expected_model_sha):
    index = strict_json(files['index_config.json'])
    embedding = strict_json(files['embedding_config.json'])
    if not isinstance(index, dict) or not isinstance(embedding, dict):
        raise IntakeError('invalidVectorDescriptor')
    dimension, rows = index.get('dimensions'), index.get('row_count')
    if type(dimension) is not int or type(rows) is not int or not 0 < dimension <= 65536 or not 0 < rows <= 1000000:
        raise IntakeError('invalidVectorDimensions')
    if embedding.get('dimensions') != dimension or embedding.get('model_sha256') != expected_model_sha or index.get('model_sha256') != expected_model_sha:
        raise IntakeError('embeddingBindingMismatch')
    if any(index.get(k) != v for k,v in dict(index_kind='EXACT_FLAT_RAW_VECTORS_NO_SEPARATE_INDEX_FILE', dtype='float32', endianness='little', layout='row_major').items()):
        raise IntakeError('unsupportedVectorLayout')
    for name,key in [('content.jsonl','content_sha256'), ('vector_map.jsonl','vector_map_sha256'), ('vectors.f32le','vector_file_sha256')]:
        if hashlib.sha256(files[name]).hexdigest() != index.get(key):
            raise IntakeError('vectorBindingHashMismatch')
    content = [strict_json(line, max_bytes=1048576) for line in files['content.jsonl'].splitlines()]
    mapping = [strict_json(line) for line in files['vector_map.jsonl'].splitlines()]
    if len(content) != rows or len(mapping) != rows or len(files['vectors.f32le']) != rows * dimension * 4:
        raise IntakeError('vectorSizeMismatch')
    ids = set()
    for i,(chunk,entry) in enumerate(zip(content,mapping)):
        if not isinstance(chunk,dict) or not isinstance(entry,dict):
            raise IntakeError('invalidVectorMap')
        identity=chunk.get('chunk_id')
        if not isinstance(identity,str) or not identity or identity in ids or entry.get('chunk_id') != identity or type(entry.get('row_index')) is not int or entry['row_index'] != i:
            raise IntakeError('invalidVectorMap')
        ids.add(identity)
    norms=[]
    for i in range(rows):
        values=struct.unpack_from('<'+str(dimension)+'f',files['vectors.f32le'],i*dimension*4)
        if not all(math.isfinite(x) for x in values):
            raise IntakeError('nonfiniteVector')
        norm=math.sqrt(sum(x*x for x in values))
        if norm == 0:
            raise IntakeError('zeroVector')
        norms.append(norm)
    return dict(rows=rows, dimensions=dimension, vector_bytes=len(files['vectors.f32le']),
                all_values_finite=True, nonzero_rows=rows, min_l2_norm=min(norms), max_l2_norm=max(norms),
                model_sha256=expected_model_sha, index_kind=index['index_kind'],
                query_prefix=embedding.get('query_input_prefix'), document_prefix=embedding.get('document_input_prefix'),
                normalization_declared=embedding.get('normalization'),
                tie_break_provisional=index.get('tie_break_provisional'),
                filter_provisional=index.get('evidence_candidate_filter_provisional'),
                null_catalog_ids={key:sum(chunk.get(key) is None for chunk in content) for key in ('pack_id','subject_id','source_id','lesson_id')},
                hashes={name:hashlib.sha256(files[name]).hexdigest() for name in ('content.jsonl','vector_map.jsonl','vectors.f32le')},
                scientific_approval='NOT RUN', android_parity='PENDING DEVICE TEST')


def inspect_biology(inspection, expected_model_sha):
    units=[]
    archive_hashes={hashlib.sha256(blob).hexdigest() for node in inspection.nodes for name,blob in node.files.items() if name.endswith('.zip')}
    registry_count=0
    # All JSON/JSONL is parsed strictly, not just the two final manifests.
    for node in inspection.nodes:
        for name,blob in node.files.items():
            if name.endswith('.json'):
                strict_json(blob,max_bytes=1048576)
            elif name.endswith('.jsonl'):
                for line in blob.splitlines(): strict_json(line,max_bytes=1048576)
        if not node.chain or 'RAG_Integration' not in node.chain[-1]:
            continue
        manifest=strict_json(node.files['manifest.json'])
        for name,entry in manifest.get('file_registry',{}).items():
            if name not in node.files or not isinstance(entry,dict) or type(entry.get('size_bytes')) is not int or len(node.files[name]) != entry['size_bytes'] or hashlib.sha256(node.files[name]).hexdigest() != entry.get('sha256'):
                raise IntakeError('registryMismatch')
            registry_count+=1
        for name,digest in manifest.get('source_files_sha256',{}).items():
            if name not in node.files or hashlib.sha256(node.files[name]).hexdigest() != digest:
                raise IntakeError('registryMismatch')
            registry_count+=1
        vectors=inspect_vector_bundle(node.files,expected_model_sha)
        dependencies=manifest.get('inputs_stage_sha256',manifest.get('source_dependencies_sha256',{}))
        units.append(dict(archive=node.chain[-1], vectors=vectors,
                          source_archive_dependencies={name:dict(sha256=digest,present_in_supplied_container=digest in archive_hashes) for name,digest in dependencies.items()},
                          dataset_revision=manifest.get('dataset_revision'), rag_ready_declared=manifest.get('rag_ready'),
                          identity_status=manifest.get('identity_status',manifest.get('flutter_catalog'))))
    if len(units)!=2 or not any('/Unit_01/' in u['archive'] for u in units) or not any('/Unit_02/' in u['archive'] for u in units):
        raise IntakeError('unexpectedBiologyUnits')
    return dict(status='PASS', scope='STATIC_BYTES_AND_BINDINGS_ONLY', archives=len(inspection.nodes),
                files=sum(len(n.files) for n in inspection.nodes), expanded_bytes=inspection.expanded_bytes,
                checksum_files=inspection.checksum_files, verified_checksums=inspection.verified_checksums,
                verified_manifest_file_entries=registry_count, units=units,
                production_schema_compatible='BLOCKED', production_approval='BLOCKED')
